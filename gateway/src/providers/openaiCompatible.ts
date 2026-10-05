/**
 * OpenAI-compatible streaming adapter (M3-T18): Groq is the backup cloud model.
 *
 * `POST {baseUrl}/chat/completions` with `stream: true` and a bearer key. The same
 * adapter covers xAI / OpenRouter / Mistral later through another base URL, if one is
 * ever enabled. `choices[0].delta.content` -> `delta` (reasoning fields skipped),
 * `[DONE]` (or a finish reason followed by EOF) -> `done` with usage from `usage` or
 * Groq's `x_groq.usage`, `content_filter` -> `bad_request`. HTTP failures map through
 * `classifyStatus`; a 429 carries `Retry-After`. Nothing here logs payloads.
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
  retryAfterHeader,
  upstreamPrompt,
  type FetchLike,
  type UpstreamPrompt,
} from "./upstream";

export const GROQ_BASE_URL = "https://api.groq.com/openai/v1";

export interface OpenAICompatibleOptions {
  /** Provider id for logs and routing (`groq`, later `xai`, ...). */
  id: string;
  baseUrl: string;
  /** Worker secret (`GROQ_API_KEY`, ...). Missing means the candidate is unavailable. */
  apiKey: string | undefined;
  model: string;
  /** Output cap field: Groq and current OpenAI use `max_completion_tokens`. */
  maxTokensField?: "max_tokens" | "max_completion_tokens";
  fetch?: FetchLike;
}

/** Chat Completions request body for a prompt (exported for payload tests). */
export function openAICompatibleBody(
  model: string,
  prompt: UpstreamPrompt,
  maxTokens: number | undefined,
  maxTokensField: "max_tokens" | "max_completion_tokens" = "max_completion_tokens",
) {
  const messages: { role: string; content: string }[] = [];
  if (prompt.system !== "") messages.push({ role: "system", content: prompt.system });
  for (const turn of prompt.turns) messages.push({ role: turn.role, content: turn.content });
  const body: Record<string, unknown> = {
    model,
    messages,
    stream: true,
    stream_options: { include_usage: true },
  };
  if (maxTokens !== undefined) body[maxTokensField] = maxTokens;
  return body;
}

function chunkUsage(chunk: Record<string, unknown>): Usage | undefined {
  const usage = asRecord(chunk.usage) ?? asRecord(asRecord(chunk.x_groq)?.usage);
  if (usage === null) return undefined;
  const promptTokens = asCount(usage.prompt_tokens);
  const completionTokens = asCount(usage.completion_tokens);
  if (promptTokens === undefined || completionTokens === undefined) return undefined;
  return { promptTokens, completionTokens };
}

export class OpenAICompatibleProvider implements Provider {
  readonly id: string;
  private readonly fetchImpl: FetchLike;
  private readonly baseUrl: string;

  constructor(private readonly options: OpenAICompatibleOptions) {
    this.id = options.id;
    this.fetchImpl = options.fetch ?? ((input, init) => fetch(input, init));
    this.baseUrl = options.baseUrl.replace(/\/+$/, "");
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

    const response = await postJson(
      this.fetchImpl,
      `${this.baseUrl}/chat/completions`,
      { authorization: `Bearer ${apiKey}` },
      openAICompatibleBody(
        this.options.model,
        prompt,
        outputTokenCap(request),
        this.options.maxTokensField,
      ),
      signal,
    );
    if (!(response instanceof Response)) {
      yield response;
      return;
    }
    if (!response.ok) {
      const code = classifyStatus(response.status);
      void response.body?.cancel().catch(() => undefined);
      yield errorChunk(code, code === "rate_limited" ? retryAfterHeader(response.headers) : undefined);
      return;
    }
    if (response.body === null) {
      yield errorChunk("upstream_unavailable");
      return;
    }

    let usage: Usage | undefined;
    let finished = false;
    for await (const data of readSseData(response.body)) {
      if (data.trim() === "[DONE]") {
        yield { type: "done", usage };
        return;
      }
      const chunk = parseJsonObject(data);
      if (chunk === null) {
        yield errorChunk("upstream_unavailable");
        return;
      }
      if (chunk.error !== undefined) {
        yield errorChunk("upstream_unavailable");
        return;
      }
      usage = chunkUsage(chunk) ?? usage;

      const choice = Array.isArray(chunk.choices) ? asRecord(chunk.choices[0]) : null;
      if (choice === null) continue; // e.g. the trailing usage-only chunk
      const content = asRecord(choice.delta)?.content;
      if (typeof content === "string" && content !== "") yield { type: "delta", text: content };
      const reason = choice.finish_reason;
      if (reason === "content_filter") {
        yield errorChunk("bad_request");
        return;
      }
      if (typeof reason === "string") finished = true;
    }
    // EOF without `[DONE]`: complete only if a finish reason arrived.
    if (finished) yield { type: "done", usage };
  }
}

/** Groq preset (backup cloud model, `GROQ_API_KEY`). */
export function groqProvider(
  apiKey: string | undefined,
  model: string,
  fetchImpl?: FetchLike,
): OpenAICompatibleProvider {
  return new OpenAICompatibleProvider({
    id: "groq",
    baseUrl: GROQ_BASE_URL,
    apiKey,
    model,
    maxTokensField: "max_completion_tokens",
    fetch: fetchImpl,
  });
}
