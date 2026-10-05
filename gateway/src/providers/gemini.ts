/**
 * Gemini adapter (M3-T18): the main cloud model.
 *
 * `POST {base}/models/{model}:streamGenerateContent?alt=sse` with the key in the
 * `x-goog-api-key` header (never in the URL). Upstream chunks become v1 chunks:
 * text parts -> `delta` (thought parts skipped), `STOP` / `MAX_TOKENS` -> `done` with
 * usage, other finish reasons or a blocked prompt -> `bad_request`. HTTP failures map
 * through `classifyStatus`; a 429 carries `Retry-After` or Gemini's `RetryInfo` delay,
 * and a 400 `API_KEY_INVALID` is `upstream_unavailable` (the gateway's key, not the app).
 *
 * The free tier trains on prompts, so the router (M3-T20) always sends it minimal
 * context. This adapter renders whatever context it is given and logs nothing.
 */

import type { Provider, ProviderChunk, ProviderStreamCall, Usage } from "../stream";
import { readSseData } from "./sse";
import {
  asCount,
  asRecord,
  classifyStatus,
  errorChunk,
  outputTokenCap,
  parseJsonObject,
  postJson,
  readErrorBody,
  retryAfterHeader,
  upstreamPrompt,
  type FetchLike,
  type UpstreamPrompt,
} from "./upstream";

export const GEMINI_BASE_URL = "https://generativelanguage.googleapis.com/v1beta";

export interface GeminiOptions {
  /** `GEMINI_API_KEY` Worker secret. Missing means the candidate is unavailable. */
  apiKey: string | undefined;
  model: string;
  baseUrl?: string;
  fetch?: FetchLike;
}

const DONE_REASONS = new Set(["STOP", "MAX_TOKENS"]);

/** Gemini request body for a prompt (exported for payload tests). */
export function geminiBody(prompt: UpstreamPrompt, maxOutputTokens: number | undefined) {
  const body: Record<string, unknown> = {
    contents: prompt.turns.map((turn) => ({
      role: turn.role === "assistant" ? "model" : "user",
      parts: [{ text: turn.content }],
    })),
  };
  if (prompt.system !== "") body.systemInstruction = { parts: [{ text: prompt.system }] };
  if (maxOutputTokens !== undefined) body.generationConfig = { maxOutputTokens };
  return body;
}

/** Seconds from Gemini's `RetryInfo.retryDelay` (e.g. "17s", "1.5s"), or undefined. */
export function geminiRetryDelay(errorBody: string): number | undefined {
  const details = asRecord(parseJsonObject(errorBody)?.error)?.details;
  if (!Array.isArray(details)) return undefined;
  for (const detail of details) {
    const delay = asRecord(detail)?.retryDelay;
    if (typeof delay !== "string") continue;
    const match = /^(\d+(?:\.\d+)?)s$/.exec(delay.trim());
    if (match !== null) return Math.ceil(Number(match[1]));
  }
  return undefined;
}

function geminiUsage(chunk: Record<string, unknown>): Usage | undefined {
  const usage = asRecord(chunk.usageMetadata);
  if (usage === null) return undefined;
  const promptTokens = asCount(usage.promptTokenCount);
  const completionTokens = asCount(usage.candidatesTokenCount) ?? 0;
  return promptTokens === undefined ? undefined : { promptTokens, completionTokens };
}

/** True when a Gemini error body says the API key itself is invalid. */
export function geminiKeyInvalid(errorBody: string): boolean {
  const details = asRecord(parseJsonObject(errorBody)?.error)?.details;
  if (!Array.isArray(details)) return false;
  return details.some((detail) => asRecord(detail)?.reason === "API_KEY_INVALID");
}

async function failure(response: Response): Promise<ProviderChunk> {
  const code = classifyStatus(response.status);
  if (code === "rate_limited") {
    const header = retryAfterHeader(response.headers);
    return errorChunk(code, header ?? geminiRetryDelay(await readErrorBody(response)));
  }
  if (code === "bad_request") {
    // Gemini reports a bad gateway key as 400 INVALID_ARGUMENT / API_KEY_INVALID. That is
    // the gateway's secret, not the app's request: report it like an upstream 401.
    const body = await readErrorBody(response);
    return errorChunk(geminiKeyInvalid(body) ? "upstream_unavailable" : "bad_request");
  }
  void response.body?.cancel().catch(() => undefined);
  return errorChunk(code);
}

export class GeminiProvider implements Provider {
  readonly id = "gemini";
  private readonly fetchImpl: FetchLike;
  private readonly baseUrl: string;

  constructor(private readonly options: GeminiOptions) {
    this.fetchImpl = options.fetch ?? ((input, init) => fetch(input, init));
    this.baseUrl = (options.baseUrl ?? GEMINI_BASE_URL).replace(/\/+$/, "");
  }

  async *stream({ request, signal }: ProviderStreamCall): AsyncGenerator<ProviderChunk> {
    const apiKey = this.options.apiKey?.trim();
    if (!apiKey) {
      yield errorChunk("upstream_unavailable");
      return;
    }
    const prompt = upstreamPrompt(request);
    if (prompt === null) {
      yield errorChunk("bad_request");
      return;
    }

    const url = `${this.baseUrl}/models/${encodeURIComponent(this.options.model)}:streamGenerateContent?alt=sse`;
    const response = await postJson(
      this.fetchImpl,
      url,
      { "x-goog-api-key": apiKey },
      geminiBody(prompt, outputTokenCap(request)),
      signal,
    );
    if (!(response instanceof Response)) {
      yield response;
      return;
    }
    if (!response.ok) {
      yield await failure(response);
      return;
    }
    if (response.body === null) {
      yield errorChunk("upstream_unavailable");
      return;
    }

    let usage: Usage | undefined;
    for await (const data of readSseData(response.body)) {
      const chunk = parseJsonObject(data);
      if (chunk === null) {
        yield errorChunk("upstream_unavailable");
        return;
      }
      if (chunk.error !== undefined) {
        const status = asCount(asRecord(chunk.error)?.code);
        yield errorChunk(status === 429 ? "rate_limited" : "upstream_unavailable");
        return;
      }
      usage = geminiUsage(chunk) ?? usage;

      const candidate = Array.isArray(chunk.candidates) ? asRecord(chunk.candidates[0]) : null;
      if (candidate === null) {
        // No candidate: a blocked prompt ends the stream; anything else is a usage-only chunk.
        if (asRecord(chunk.promptFeedback)?.blockReason !== undefined) {
          yield errorChunk("bad_request");
          return;
        }
        continue;
      }
      const parts = asRecord(candidate.content)?.parts;
      if (Array.isArray(parts)) {
        for (const part of parts) {
          const record = asRecord(part);
          if (record === null || record.thought === true || typeof record.text !== "string") continue;
          if (record.text !== "") yield { type: "delta", text: record.text };
        }
      }
      const reason = candidate.finishReason;
      if (typeof reason === "string" && reason !== "FINISH_REASON_UNSPECIFIED") {
        yield DONE_REASONS.has(reason) ? { type: "done", usage } : errorChunk("bad_request");
        return;
      }
    }
    // Ended without a finish reason: the stream layer reports it as incomplete.
  }
}
