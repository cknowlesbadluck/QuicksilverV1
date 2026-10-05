/**
 * Protocol v1 unified stream (M3-T17). See docs/GATEWAY_PROTOCOL.md.
 *
 * Providers yield `ProviderChunk`s (delta / done / error). `openV1Stream` turns them into
 * protocol v1 SSE bytes and enforces the stream grammar:
 *
 * - Success: `meta` -> zero or more `delta` -> `done`.
 * - Failure before output: a single `error` event and no `meta`. `openV1Stream` reports it
 *   as `{ ok: false }` before any byte is sent, so the router (M3-T20) can fail over.
 * - Failure after output: `meta` -> deltas -> `error`. A provider that throws or ends
 *   without a terminal chunk gets an `upstream_unavailable` error, never a silent end.
 *
 * Privacy: nothing here logs request or response bodies.
 */

export type ErrorCode =
  | "unauthorized"
  | "rate_limited"
  | "budget_exhausted"
  | "upstream_unavailable"
  | "bad_request"
  | "timeout";

export interface Meta {
  route: string;
  model: string;
  trainsOnPrompts: boolean;
}

export interface Usage {
  promptTokens: number;
  completionTokens: number;
}

export interface ErrorData {
  code: ErrorCode;
  retryAfter?: number;
}

export type V1Event =
  | { event: "meta"; data: Meta }
  | { event: "delta"; data: { text: string } }
  | { event: "done"; data: { usage?: Usage } }
  | { event: "error"; data: ErrorData };

/** What a provider adapter yields. `meta` is added by the stream layer. */
export type ProviderChunk =
  | { type: "delta"; text: string }
  | { type: "done"; usage?: Usage }
  | { type: "error"; code: ErrorCode; retryAfter?: number };

export type ContextKind = "history" | "summary" | "memory" | "device";
export type Privacy = "device" | "ephemeral" | "cloud";

/** `POST /v1/chat` body (shape only; validation lands with the router, M3-T20). */
export interface ChatRequestV1 {
  taskTier: string;
  messages: { role: string; content: string }[];
  context: { kind: ContextKind; text: string; privacy: Privacy }[];
  privacy: Privacy;
  maxTokens: number;
}

export interface ProviderStreamCall {
  request: ChatRequestV1;
  /** Aborted when the client disconnects or the router gives up on this attempt. */
  signal: AbortSignal;
}

/** One upstream adapter (fake now; Gemini, OpenAI-compatible, Workers AI in M3-T18/T19). */
export interface Provider {
  readonly id: string;
  stream(call: ProviderStreamCall): AsyncIterable<ProviderChunk>;
}

function integral(value: number | undefined): number | undefined {
  if (value === undefined || !Number.isFinite(value) || value < 0) return undefined;
  return Math.ceil(value);
}

/** Protocol v1 integers only; `rate_limited` always carries a `retryAfter` (>= 1 s). */
export function normalizeError(code: ErrorCode, retryAfter?: number): ErrorData {
  const seconds = integral(retryAfter);
  if (code === "rate_limited") return { code, retryAfter: Math.max(1, seconds ?? 1) };
  return seconds === undefined ? { code } : { code, retryAfter: seconds };
}

function normalizeUsage(usage: Usage | undefined): Usage | undefined {
  if (usage === undefined) return undefined;
  const promptTokens = integral(usage.promptTokens);
  const completionTokens = integral(usage.completionTokens);
  if (promptTokens === undefined || completionTokens === undefined) return undefined;
  return { promptTokens, completionTokens };
}

/** One SSE event. Key order is fixed so output matches gateway/fixtures byte for byte. */
export function encodeEvent(event: V1Event): string {
  let data: unknown;
  switch (event.event) {
    case "meta":
      data = {
        route: event.data.route,
        model: event.data.model,
        trainsOnPrompts: event.data.trainsOnPrompts,
      };
      break;
    case "delta":
      data = { text: event.data.text };
      break;
    case "done": {
      const usage = normalizeUsage(event.data.usage);
      data = usage === undefined ? {} : { usage };
      break;
    }
    case "error":
      data = normalizeError(event.data.code, event.data.retryAfter);
      break;
  }
  return `event: ${event.event}\ndata: ${JSON.stringify(data)}\n\n`;
}

const SSE_HEADERS = {
  "content-type": "text/event-stream; charset=utf-8",
  "cache-control": "no-store",
} as const;

/** A response carrying exactly one protocol v1 `error` event. */
export function errorResponse(
  status: number,
  error: ErrorData,
  headers: Record<string, string> = {},
): Response {
  return new Response(encodeEvent({ event: "error", data: error }), {
    status,
    headers: { ...SSE_HEADERS, ...headers },
  });
}

export type OpenedStream =
  | { ok: true; body: ReadableStream<Uint8Array> }
  | { ok: false; error: ErrorData };

const UPSTREAM_UNAVAILABLE: ErrorData = { code: "upstream_unavailable" };

function chunkEvent(chunk: ProviderChunk): V1Event | null {
  switch (chunk.type) {
    case "delta":
      return chunk.text === "" ? null : { event: "delta", data: { text: chunk.text } };
    case "done":
      return { event: "done", data: { usage: chunk.usage } };
    case "error":
      return { event: "error", data: normalizeError(chunk.code, chunk.retryAfter) };
  }
}

function closeQuietly(upstream: AsyncIterator<ProviderChunk>): void {
  try {
    void upstream.return?.()?.catch(() => undefined);
  } catch {
    // Best effort: the upstream is being abandoned.
  }
}

async function* frames(
  meta: Meta,
  first: ProviderChunk,
  upstream: AsyncIterator<ProviderChunk>,
): AsyncGenerator<string> {
  try {
    yield encodeEvent({ event: "meta", data: meta });
    let chunk = first;
    for (;;) {
      const event = chunkEvent(chunk);
      if (event !== null) yield encodeEvent(event);
      if (chunk.type !== "delta") return;

      let next: IteratorResult<ProviderChunk>;
      try {
        next = await upstream.next();
      } catch {
        yield encodeEvent({ event: "error", data: UPSTREAM_UNAVAILABLE });
        return;
      }
      if (next.done) {
        // Ended without `done` or `error`: incomplete, so close it with a typed error.
        yield encodeEvent({ event: "error", data: UPSTREAM_UNAVAILABLE });
        return;
      }
      chunk = next.value;
    }
  } finally {
    // A terminal chunk may arrive before the provider's own body ends. Release it so
    // the adapter's cleanup (fetch body, reader) runs now, not at garbage collection.
    closeQuietly(upstream);
  }
}

/**
 * Waits for the provider's first chunk. An error (or throw, or empty stream) before any
 * output is returned as `{ ok: false }` with nothing sent. Otherwise the body streams
 * `meta`, then the chunks. Cancelling the body aborts `options.abort` so the upstream
 * request stops too.
 */
export async function openV1Stream(
  meta: Meta,
  source: AsyncIterable<ProviderChunk>,
  options: { abort?: AbortController } = {},
): Promise<OpenedStream> {
  const upstream = source[Symbol.asyncIterator]();

  let first: IteratorResult<ProviderChunk>;
  try {
    first = await upstream.next();
  } catch {
    return { ok: false, error: UPSTREAM_UNAVAILABLE };
  }
  if (first.done) return { ok: false, error: UPSTREAM_UNAVAILABLE };
  if (first.value.type === "error") {
    closeQuietly(upstream);
    return { ok: false, error: normalizeError(first.value.code, first.value.retryAfter) };
  }

  const encoder = new TextEncoder();
  const output = frames(meta, first.value, upstream);
  const body = new ReadableStream<Uint8Array>({
    async pull(controller) {
      const next = await output.next();
      if (next.done) {
        controller.close();
      } else {
        controller.enqueue(encoder.encode(next.value));
      }
    },
    cancel() {
      options.abort?.abort();
      // Not awaited: an upstream that ignores the abort must not hang the cancel.
      void output.return(undefined).catch(() => undefined);
      closeQuietly(upstream);
    },
  });
  return { ok: true, body };
}

/** 200 + the stream, or 200 + one typed `error` event (the app then goes on-device). */
export function streamResponse(opened: OpenedStream): Response {
  if (!opened.ok) return errorResponse(200, opened.error);
  return new Response(opened.body, { status: 200, headers: { ...SSE_HEADERS } });
}
