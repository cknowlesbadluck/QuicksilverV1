/**
 * Workers AI adapter (M3-T19): the last-resort cloud model, through the free `env.AI`
 * binding (`[ai]` in wrangler.toml). On Workers Free the daily allocation is 10,000
 * Neurons at no charge; past it, requests fail (error 3036) instead of billing.
 *
 * `env.AI.run(model, { messages, stream: true, max_tokens }, { signal })` returns an SSE
 * byte stream: `data: {"response": "..."}` chunks (some models send OpenAI-style
 * `choices[0].delta.content` instead), a final chunk that may carry `usage`, then
 * `data: [DONE]`. Text -> `delta`, `[DONE]` -> `done` with usage. A thrown binding error
 * maps by its Workers AI code (see `classifyWorkersAIError`): the daily free allocation
 * running out is `budget_exhausted`. A missing binding is `upstream_unavailable` with no
 * call. Nothing here logs payloads.
 */

import type { ErrorCode, Provider, ProviderChunk, ProviderStreamCall, Usage } from "../stream";
import { readSseData } from "./sse";
import {
  asCount,
  asRecord,
  errorChunk,
  isAbort,
  outputTokenCap,
  parseJsonObject,
  upstreamPrompt,
  type UpstreamPrompt,
} from "./upstream";

/**
 * The slice of the Workers AI binding this adapter uses. Structural, so tests pass a
 * mock and the Worker passes `env.AI` without the generated per-model types.
 */
export interface WorkersAIBinding {
  run(model: string, inputs: Record<string, unknown>, options?: { signal?: AbortSignal }): Promise<unknown>;
}

export interface WorkersAIOptions {
  /** `env.AI`. Missing means the candidate is unavailable (e.g. a local run without it). */
  binding: WorkersAIBinding | undefined;
  model: string;
}

/** `run` inputs for a prompt (exported for payload tests). */
export function workersAIInputs(prompt: UpstreamPrompt, maxTokens: number | undefined) {
  const messages: { role: string; content: string }[] = [];
  if (prompt.system !== "") messages.push({ role: "system", content: prompt.system });
  for (const turn of prompt.turns) messages.push({ role: turn.role, content: turn.content });
  const inputs: Record<string, unknown> = { messages, stream: true };
  if (maxTokens !== undefined) inputs.max_tokens = maxTokens;
  return inputs;
}

/** Workers AI internal codes (developers.cloudflare.com/workers-ai/platform/errors/). */
const CODE_MAP: Record<string, ErrorCode> = {
  "3036": "budget_exhausted", // daily free allocation used up
  "3040": "rate_limited", // capacity temporarily exceeded
  "3007": "timeout",
  "3003": "bad_request", // incomplete request
  "3006": "bad_request", // request too large
};

/**
 * Maps a thrown binding error to a v1 code. Codes that are about the gateway's own setup
 * (no such model, paid-plan-only model 5035, blocked account) are `upstream_unavailable`,
 * never `unauthorized` or `bad_request`, so the app is not told its request was wrong.
 */
export function classifyWorkersAIError(error: unknown): ErrorCode {
  const message = error instanceof Error ? error.message : typeof error === "string" ? error : "";
  // Workers AI prefixes its code (`3036: You have used up ...`); trust that one first so
  // an unmapped real code (5035) is never shadowed by a mapped number later in the text.
  const prefixed = /(?:^|[\s:])([35]\d{3}):/.exec(message)?.[1];
  if (prefixed !== undefined) return CODE_MAP[prefixed] ?? "upstream_unavailable";
  // Otherwise take the first mapped code anywhere (other numbers must not shadow it).
  for (const match of message.matchAll(/\b([35]\d{3})\b/g)) {
    const mapped = CODE_MAP[match[1] ?? ""];
    if (mapped !== undefined) return mapped;
  }
  if (/daily free allocation/i.test(message)) return "budget_exhausted";
  if (/capacity temporarily exceeded/i.test(message)) return "rate_limited";
  return "upstream_unavailable";
}

function chunkUsage(chunk: Record<string, unknown>): Usage | undefined {
  const usage = asRecord(chunk.usage);
  if (usage === null) return undefined;
  const promptTokens = asCount(usage.prompt_tokens);
  const completionTokens = asCount(usage.completion_tokens);
  if (promptTokens === undefined || completionTokens === undefined) return undefined;
  return { promptTokens, completionTokens };
}

function chunkText(chunk: Record<string, unknown>): string | undefined {
  if (typeof chunk.response === "string") return chunk.response;
  const choice = Array.isArray(chunk.choices) ? asRecord(chunk.choices[0]) : null;
  const content = asRecord(choice?.delta)?.content;
  return typeof content === "string" ? content : undefined;
}

function isByteStream(value: unknown): value is ReadableStream<Uint8Array> {
  return typeof value === "object" && value !== null && typeof (value as ReadableStream).getReader === "function";
}

export class WorkersAIProvider implements Provider {
  readonly id = "workersAI";

  constructor(private readonly options: WorkersAIOptions) {}

  async *stream({ request, signal }: ProviderStreamCall): AsyncGenerator<ProviderChunk> {
    const binding = this.options.binding;
    if (binding === undefined || typeof binding.run !== "function") {
      yield errorChunk("upstream_unavailable");
      return;
    }
    const prompt = upstreamPrompt(request);
    if (prompt === null) {
      yield errorChunk("bad_request");
      return;
    }

    let result: unknown;
    try {
      result = await binding.run(this.options.model, workersAIInputs(prompt, outputTokenCap(request)), {
        signal,
      });
    } catch (error) {
      if (isAbort(error, signal)) throw error;
      yield errorChunk(classifyWorkersAIError(error));
      return;
    }

    if (!isByteStream(result)) {
      // A non-streaming answer (`{ response }`) is accepted whole; anything else is broken.
      const record = asRecord(result);
      const text = record === null ? undefined : chunkText(record);
      if (record === null || text === undefined) {
        yield errorChunk("upstream_unavailable");
        return;
      }
      if (text !== "") yield { type: "delta", text };
      yield { type: "done", usage: chunkUsage(record) };
      return;
    }

    let usage: Usage | undefined;
    try {
      for await (const data of readSseData(result)) {
        if (data.trim() === "[DONE]") {
          yield { type: "done", usage };
          return;
        }
        const chunk = parseJsonObject(data);
        if (chunk === null || chunk.error !== undefined || chunk.errors !== undefined) {
          yield errorChunk("upstream_unavailable");
          return;
        }
        usage = chunkUsage(chunk) ?? usage;
        const text = chunkText(chunk);
        if (text !== undefined && text !== "") yield { type: "delta", text };
      }
    } catch (error) {
      if (isAbort(error, signal)) throw error;
      yield errorChunk(classifyWorkersAIError(error));
      return;
    }
    // EOF without `[DONE]`: the stream layer reports it as incomplete.
  }
}

/** Last-resort preset over `env.AI`. */
export function workersAIProvider(binding: WorkersAIBinding | undefined, model: string): WorkersAIProvider {
  return new WorkersAIProvider({ binding, model });
}
