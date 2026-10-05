import type { FetchLike } from "../src/providers/upstream";
import { openV1Stream, streamResponse, type Meta, type Provider, type ChatRequestV1 } from "../src/stream";

export interface RecordedCall {
  url: string;
  init: RequestInit;
  body: Record<string, unknown>;
  headers: Record<string, string>;
}

/** A body that arrives in `size`-byte pieces, so parsers see split lines and characters. */
export function chunkedBody(text: string, size = 7): ReadableStream<Uint8Array> {
  const bytes = new TextEncoder().encode(text);
  let offset = 0;
  return new ReadableStream<Uint8Array>({
    pull(controller) {
      if (offset >= bytes.length) {
        controller.close();
        return;
      }
      controller.enqueue(bytes.slice(offset, offset + size));
      offset += size;
    },
  });
}

/** Fake fetch: records each call and answers with `respond()` (no network). */
export function fakeFetch(respond: () => Response | Promise<Response>): {
  fetch: FetchLike;
  calls: RecordedCall[];
} {
  const calls: RecordedCall[] = [];
  const fetch: FetchLike = async (url, init) => {
    calls.push({
      url,
      init,
      body: JSON.parse(String(init.body)) as Record<string, unknown>,
      headers: init.headers as Record<string, string>,
    });
    return respond();
  };
  return { fetch, calls };
}

export function sseResponse(text: string, init: ResponseInit = {}): Response {
  return new Response(chunkedBody(text), {
    status: 200,
    headers: { "content-type": "text/event-stream" },
    ...init,
  });
}

export const META: Meta = { route: "cloud", model: "upstream-model", trainsOnPrompts: true };

/** Runs a provider through the v1 stream layer and returns the client-visible bytes. */
export async function v1Text(provider: Provider, request: ChatRequestV1): Promise<string> {
  const abort = new AbortController();
  const opened = await openV1Stream(META, provider.stream({ request, signal: abort.signal }), { abort });
  return streamResponse(opened).text();
}

export function sse(...events: string[]): string {
  return events.join("");
}
