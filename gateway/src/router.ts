/**
 * Router (M3-T20): picks a candidate, fails over before the first delta, enforces
 * per-attempt timeouts, propagates cancellation, and serves the client-safe `/v1/config`.
 *
 * Order is `config/routing.json`: main (Gemini Flash) -> backup (Groq gpt-oss-120b) ->
 * last resort (Workers AI). After the last candidate the app goes on-device (M3.5-T3).
 *
 * - A candidate whose secret (or binding) is missing is skipped, so xAI stays optional.
 * - A candidate with no daily budget left is skipped (`DailyBudgets.tryConsume`).
 * - Failover happens on `rate_limited`, `upstream_unavailable`, `timeout` and
 *   `budget_exhausted`, and **only before the first delta**. Once output has begun the
 *   stream is committed: a later failure closes it with a typed `error`.
 * - `bad_request` is returned as is: the request itself can't be served as sent.
 * - **Per-candidate redaction:** before each attempt the request is cut down to the
 *   context level that candidate allows. A `trainsOnPrompts` candidate gets `minimal`
 *   (system + the question + the last 2 turns, no context blocks at all), so failing over
 *   can never widen what a training provider sees.
 *
 * Privacy: nothing here logs request or response bodies, keys or tokens.
 */

import {
  TIER_ORDER,
  type Candidate,
  type DailyBudgets,
  type RouterTimeouts,
  type RoutingConfig,
  type Tier,
} from "./limits";
import { GeminiProvider } from "./providers/gemini";
import { OpenAICompatibleProvider, groqProvider } from "./providers/openaiCompatible";
import type { FetchLike } from "./providers/upstream";
import { workersAIProvider, type WorkersAIBinding } from "./providers/workersAI";
import {
  openV1Stream,
  type ChatRequestV1,
  type ContextKind,
  type ErrorCode,
  type ErrorData,
  type OpenedStream,
  type Privacy,
  type Provider,
  type ProviderChunk,
} from "./stream";

// MARK: - Request validation

const ROLES = new Set(["system", "user", "assistant"]);
const CONTEXT_KINDS = new Set<ContextKind>(["history", "summary", "memory", "device"]);
const PRIVACY = new Set<Privacy>(["device", "ephemeral", "cloud"]);

/** Bounds that keep one request well inside the Workers Free CPU budget. */
export const MAX_MESSAGES = 48;
export const MAX_CONTEXT_BLOCKS = 16;
export const MAX_TEXT_CHARS = 16_000;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isBoundedText(value: unknown): value is string {
  return typeof value === "string" && value.length <= MAX_TEXT_CHARS;
}

/**
 * Validates a `POST /v1/chat` body against protocol v1. Returns null (-> `bad_request`)
 * for anything malformed: wrong types, an unknown role / kind / privacy, no user turn
 * last, a non-positive or fractional `maxTokens`, or oversize input.
 */
export function validateChatRequest(body: unknown): ChatRequestV1 | null {
  if (!isRecord(body)) return null;
  const { taskTier, messages, context, privacy, maxTokens } = body;
  if (typeof taskTier !== "string") return null;
  if (typeof privacy !== "string" || !PRIVACY.has(privacy as Privacy)) return null;
  if (typeof maxTokens !== "number" || !Number.isInteger(maxTokens) || maxTokens <= 0) return null;

  if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES) {
    return null;
  }
  const cleanMessages: ChatRequestV1["messages"] = [];
  for (const message of messages) {
    if (!isRecord(message)) return null;
    if (typeof message.role !== "string" || !ROLES.has(message.role)) return null;
    if (!isBoundedText(message.content)) return null;
    cleanMessages.push({ role: message.role, content: message.content });
  }
  const turns = cleanMessages.filter((message) => message.role !== "system");
  if (turns.length === 0 || turns[turns.length - 1]?.role !== "user") return null;

  if (!Array.isArray(context) || context.length > MAX_CONTEXT_BLOCKS) return null;
  const cleanContext: ChatRequestV1["context"] = [];
  for (const block of context) {
    if (!isRecord(block)) return null;
    if (typeof block.kind !== "string" || !CONTEXT_KINDS.has(block.kind as ContextKind)) return null;
    if (typeof block.privacy !== "string" || !PRIVACY.has(block.privacy as Privacy)) return null;
    if (!isBoundedText(block.text)) return null;
    cleanContext.push({
      kind: block.kind as ContextKind,
      text: block.text,
      privacy: block.privacy as Privacy,
    });
  }

  return {
    taskTier,
    messages: cleanMessages,
    context: cleanContext,
    privacy: privacy as Privacy,
    maxTokens,
  };
}

// MARK: - Per-candidate redaction

export type ContextLevel = "standard" | "minimal";

/** Mirrors the app's `CloudContextPolicy` caps (M3-T11). */
export const STANDARD_TURN_CAP = 4;
export const MINIMAL_TURN_CAP = 2;
export const STANDARD_MEMORY_CAP = 3;

/** A candidate that trains on prompts can only ever get `minimal`. */
export function contextLevel(candidate: Pick<Candidate, "trainsOnPrompts">): ContextLevel {
  return candidate.trainsOnPrompts ? "minimal" : "standard";
}

const STANDARD_BLOCK_CAPS: Record<ContextKind, number> = {
  summary: 1,
  history: STANDARD_TURN_CAP,
  memory: STANDARD_MEMORY_CAP,
  device: 1,
};

/**
 * The question (last message) plus the longest contiguous run of earlier messages with at
 * most `turnCap` user and at most `turnCap` assistant messages. Counting each role keeps
 * the bound even when the history doesn't alternate (a failed turn leaves two user
 * messages in a row; a crafted body could repeat assistant messages), so a minimal
 * candidate never sees more than 2 user and 2 assistant messages before the question.
 */
export function recentTurns(
  conversation: ChatRequestV1["messages"],
  turnCap: number,
): ChatRequestV1["messages"] {
  const question = conversation[conversation.length - 1];
  if (question === undefined) return [];
  const used = { user: 0, assistant: 0 };
  let start = conversation.length - 1;
  while (start > 0) {
    const role = conversation[start - 1]?.role === "assistant" ? "assistant" : "user";
    if (used[role] >= turnCap) break;
    used[role] += 1;
    start -= 1;
  }
  return conversation.slice(start);
}

/**
 * The request this candidate may see. System messages are kept; the conversation is cut
 * to the question plus the last N prior turns (N = 2 minimal, 4 standard; a turn is a
 * user + assistant pair, bounded per role by `recentTurns`). `minimal` drops every context block (memory, device, summary
 * and history); `standard` keeps them up to the app's caps. `maxTokens` is clamped to the
 * candidate's `maxOutputTokens`. The input is never mutated.
 */
export function redactFor(request: ChatRequestV1, candidate: Candidate): ChatRequestV1 {
  const level = contextLevel(candidate);
  const turnCap = level === "minimal" ? MINIMAL_TURN_CAP : STANDARD_TURN_CAP;
  const system = request.messages.filter((message) => message.role === "system");
  const conversation = request.messages.filter((message) => message.role !== "system");
  const kept = recentTurns(conversation, turnCap);

  let context: ChatRequestV1["context"] = [];
  if (level === "standard") {
    const used: Record<ContextKind, number> = { summary: 0, history: 0, memory: 0, device: 0 };
    context = request.context.filter((block) => {
      if (used[block.kind] >= STANDARD_BLOCK_CAPS[block.kind]) return false;
      used[block.kind] += 1;
      return true;
    });
  }

  return {
    taskTier: request.taskTier,
    messages: [...system, ...kept].map((message) => ({ ...message })),
    context: context.map((block) => ({ ...block })),
    privacy: request.privacy,
    maxTokens: Math.min(request.maxTokens, candidate.maxOutputTokens),
  };
}

// MARK: - Providers

/** Worker secrets and bindings the router reads (set by Christopher at HG3). */
export interface ProviderEnv {
  GEMINI_API_KEY?: string;
  GROQ_API_KEY?: string;
  /** Optional: only if Christopher buys xAI credits himself. */
  XAI_API_KEY?: string;
  AI?: WorkersAIBinding;
}

export const XAI_BASE_URL = "https://api.x.ai/v1";

/** Returns the adapter for a candidate, or null when it can't run here (skipped). */
export type ProviderResolver = (candidate: Candidate) => Provider | null;

function present(secret: string | undefined): string | null {
  const value = secret?.trim();
  return value ? value : null;
}

/** Real adapters from Worker secrets. A missing secret or binding means "skip". */
export function envProviders(env: ProviderEnv, fetchImpl?: FetchLike): ProviderResolver {
  return (candidate) => {
    switch (candidate.provider) {
      case "gemini": {
        const apiKey = present(env.GEMINI_API_KEY);
        return apiKey === null
          ? null
          : new GeminiProvider({ apiKey, model: candidate.model, fetch: fetchImpl });
      }
      case "groq": {
        const apiKey = present(env.GROQ_API_KEY);
        return apiKey === null ? null : groqProvider(apiKey, candidate.model, fetchImpl);
      }
      case "xai": {
        const apiKey = present(env.XAI_API_KEY);
        return apiKey === null
          ? null
          : new OpenAICompatibleProvider({
              id: "xai",
              baseUrl: XAI_BASE_URL,
              apiKey,
              model: candidate.model,
              maxTokensField: "max_tokens",
              fetch: fetchImpl,
            });
      }
      case "workersAI":
        return env.AI === undefined || typeof env.AI.run !== "function"
          ? null
          : workersAIProvider(env.AI, candidate.model);
      default:
        return null;
    }
  };
}

// MARK: - Timeouts

const TIMED_OUT = Symbol("timed out");

/** Resolves with the iterator result, or `TIMED_OUT` after `ms`. The loser never leaks. */
function nextWithin<T>(
  iterator: AsyncIterator<T>,
  ms: number,
): Promise<IteratorResult<T> | typeof TIMED_OUT> {
  const next = iterator.next();
  let timer: ReturnType<typeof setTimeout> | null = null;
  const timeout = new Promise<typeof TIMED_OUT>((resolve) => {
    timer = setTimeout(() => resolve(TIMED_OUT), ms);
  });
  // If the timer wins, a later rejection (the aborted upstream) must not go unhandled.
  next.catch(() => undefined);
  return Promise.race([next, timeout]).finally(() => {
    if (timer !== null) clearTimeout(timer);
  });
}

/**
 * Wraps a provider stream with the router's timeouts. No first chunk within
 * `firstByteMs`, or no next chunk within `idleMs` once output began, aborts the attempt
 * and yields a `timeout` error: before output that triggers failover, after output it
 * closes the stream.
 */
export async function* withTimeouts(
  source: AsyncIterable<ProviderChunk>,
  attempt: AbortController,
  timeouts: RouterTimeouts,
): AsyncGenerator<ProviderChunk> {
  const upstream = source[Symbol.asyncIterator]();
  let waitMs = timeouts.firstByteMs;
  try {
    for (;;) {
      const next = await nextWithin(upstream, waitMs);
      if (next === TIMED_OUT) {
        attempt.abort();
        yield { type: "error", code: "timeout" };
        return;
      }
      if (next.done) return;
      yield next.value;
      if (next.value.type !== "delta") return;
      waitMs = timeouts.idleMs;
    }
  } finally {
    try {
      void upstream.return?.()?.catch(() => undefined);
    } catch {
      // Best effort: the attempt is over.
    }
  }
}

// MARK: - Routing

const FAILOVER_CODES = new Set<ErrorCode>([
  "rate_limited",
  "upstream_unavailable",
  "timeout",
  "budget_exhausted",
]);

export function shouldFailOver(code: ErrorCode): boolean {
  return FAILOVER_CODES.has(code);
}

export interface RouteOptions {
  config: RoutingConfig;
  budgets: DailyBudgets;
  providers: ProviderResolver;
  now: number;
  /** The client's request signal: aborting it cancels the current upstream attempt. */
  signal?: AbortSignal;
}

/** Candidates in failover order, each with the tier it came from (the `meta.route`). */
function candidatesInOrder(config: RoutingConfig): { tier: Tier; candidate: Candidate }[] {
  return TIER_ORDER.flatMap((tier) =>
    (config.tiers[tier] ?? []).map((candidate) => ({ tier, candidate })),
  );
}

/**
 * Tries each candidate in order until one produces output. Returns the open stream, or
 * `{ ok: false }` with the error the app should see: the last attempt's error, else
 * `budget_exhausted` when budgets were the only reason nothing ran, else
 * `upstream_unavailable` (nothing configured).
 */
export async function routeChat(request: ChatRequestV1, options: RouteOptions): Promise<OpenedStream> {
  let lastError: ErrorData | null = null;
  let budgetSkipped = false;

  for (const { tier, candidate } of candidatesInOrder(options.config)) {
    if (options.signal?.aborted) return { ok: false, error: { code: "upstream_unavailable" } };

    const provider = options.providers(candidate);
    if (provider === null) continue;
    if (!options.budgets.tryConsume(candidate, options.now)) {
      budgetSkipped = true;
      continue;
    }

    const attempt = new AbortController();
    const onClientAbort = () => attempt.abort();
    options.signal?.addEventListener("abort", onClientAbort, { once: true });

    const source = provider.stream({ request: redactFor(request, candidate), signal: attempt.signal });
    const opened = await openV1Stream(
      { route: tier, model: candidate.model, trainsOnPrompts: candidate.trainsOnPrompts },
      withTimeouts(source, attempt, options.config.timeouts),
      { abort: attempt },
    );
    if (opened.ok) return opened;

    options.signal?.removeEventListener("abort", onClientAbort);
    attempt.abort();
    lastError = opened.error;
    if (!shouldFailOver(opened.error.code)) return opened;
  }

  if (lastError !== null) return { ok: false, error: lastError };
  return { ok: false, error: { code: budgetSkipped ? "budget_exhausted" : "upstream_unavailable" } };
}

// MARK: - GET /v1/config

/** Client timeouts in seconds (the app's `GatewayAIProvider`); the router's are tighter. */
export const CLIENT_TIMEOUTS = { connect: 10, firstEvent: 20, idle: 15, total: 90 } as const;

/**
 * The routing policy the app caches (docs/GATEWAY_PROTOCOL.md). Client-safe only: tier
 * labels, `trainsOnPrompts` and the context level, never provider ids, budgets or keys.
 * A tier trains on prompts if any of its candidates does, and is then `minimal`.
 */
export function clientConfig(config: RoutingConfig) {
  const tiers: Record<string, { displayModel: string; trainsOnPrompts: boolean; contextLevel: ContextLevel }> = {};
  for (const tier of TIER_ORDER) {
    const candidates = config.tiers[tier] ?? [];
    const first = candidates[0];
    if (first === undefined) continue;
    const trainsOnPrompts = candidates.some((candidate) => candidate.trainsOnPrompts);
    tiers[tier] = {
      displayModel: first.displayModel,
      trainsOnPrompts,
      contextLevel: contextLevel({ trainsOnPrompts }),
    };
  }
  return {
    protocol: "v1",
    stream: ["meta", "delta", "done", "error"],
    tasks: {
      answer: { route: "cloud", tier: "main" },
      plan: { route: "onDevice" },
      tools: { route: "onDevice" },
      memory: { route: "onDevice" },
      summaries: { route: "onDevice" },
    },
    tiers,
    timeouts: { ...CLIENT_TIMEOUTS },
    retry: { maxAttempts: 1, honorRetryAfter: true },
  };
}
