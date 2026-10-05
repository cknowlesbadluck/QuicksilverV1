import { describe, expect, it } from "vitest";
import chatRequestJson from "../fixtures/chat-request.json?raw";
import configJson from "../fixtures/config.json?raw";
import geminiHappySse from "../fixtures/upstream/gemini-happy.sse?raw";
import workersAIHappySse from "../fixtures/upstream/workers-ai-happy.sse?raw";
import { createState, handleRequest } from "../src/index";
import {
  DailyBudgets,
  orderedCandidates,
  routingConfig,
  type Candidate,
  type RoutingConfig,
} from "../src/limits";
import { FakeProvider, type FakeStep } from "../src/providers/fake";
import type { FetchLike } from "../src/providers/upstream";
import type { WorkersAIBinding } from "../src/providers/workersAI";
import {
  CLIENT_TIMEOUTS,
  MINIMAL_TURN_CAP,
  clientConfig,
  envProviders,
  redactFor,
  routeChat,
  validateChatRequest,
  withTimeouts,
  type ProviderResolver,
} from "../src/router";
import { streamResponse, type ChatRequestV1, type Provider, type ProviderStreamCall } from "../src/stream";
import { chunkedBody, sse } from "./upstreamHelpers";

const T0 = Date.parse("2026-10-05T12:00:00.000Z");
const TOKEN = "test-device-token-not-a-secret";

const MEMORY = "Christopher prefers dark roast";
const DEVICE = "battery low";
const SUMMARY = "We talked about the Forge";

/** Five prior turns, so both the minimal (2) and standard (4) caps bite. */
const REQUEST: ChatRequestV1 = {
  taskTier: "standard",
  messages: [
    { role: "system", content: "You are Quicksilver." },
    { role: "user", content: "u1" },
    { role: "assistant", content: "a1" },
    { role: "user", content: "u2" },
    { role: "assistant", content: "a2" },
    { role: "user", content: "u3" },
    { role: "assistant", content: "a3" },
    { role: "user", content: "u4" },
    { role: "assistant", content: "a4" },
    { role: "user", content: "u5" },
    { role: "assistant", content: "a5" },
    { role: "user", content: "What now?" },
  ],
  context: [
    { kind: "memory", text: MEMORY, privacy: "device" },
    { kind: "device", text: DEVICE, privacy: "device" },
    { kind: "summary", text: SUMMARY, privacy: "device" },
  ],
  privacy: "device",
  maxTokens: 4096,
};

const [GEMINI, GROQ, WORKERS_AI] = orderedCandidates(routingConfig) as [Candidate, Candidate, Candidate];

const ev = {
  meta: (route: string, model: string, trains: boolean) =>
    `event: meta\ndata: {"route":"${route}","model":"${model}","trainsOnPrompts":${trains}}\n\n`,
  delta: (text: string) => `event: delta\ndata: {"text":"${text}"}\n\n`,
  done: () => "event: done\ndata: {}\n\n",
  error: (code: string, retryAfter?: number) =>
    `event: error\ndata: ${JSON.stringify(retryAfter === undefined ? { code } : { code, retryAfter })}\n\n`,
};

/** A scripted provider that records the request and signal of every attempt. */
class Scripted implements Provider {
  readonly calls: ProviderStreamCall[] = [];
  private readonly fake: FakeProvider;

  constructor(
    readonly id: string,
    steps: FakeStep[],
  ) {
    this.fake = new FakeProvider({ meta: { route: "x", model: "x", trainsOnPrompts: false }, steps });
  }

  stream(call: ProviderStreamCall) {
    this.calls.push(call);
    return this.fake.stream(call);
  }
}

function resolver(map: Record<string, Provider | null>): ProviderResolver {
  return (candidate) => map[candidate.provider] ?? null;
}

function fastConfig(firstByteMs = 25, idleMs = 25): RoutingConfig {
  return { ...routingConfig, timeouts: { firstByteMs, idleMs } };
}

async function route(
  providers: ProviderResolver,
  options: { config?: RoutingConfig; budgets?: DailyBudgets; signal?: AbortSignal } = {},
) {
  const opened = await routeChat(REQUEST, {
    config: options.config ?? routingConfig,
    budgets: options.budgets ?? new DailyBudgets(),
    providers,
    now: T0,
    signal: options.signal,
  });
  return { opened, text: () => streamResponse(opened).text() };
}

describe("router failover", () => {
  it("fails over in order Gemini -> Groq -> Workers AI before any output", async () => {
    const gemini = new Scripted("gemini", [{ type: "error", code: "rate_limited", retryAfter: 3 }]);
    const groq = new Scripted("groq", [{ type: "error", code: "upstream_unavailable" }]);
    const workers = new Scripted("workersAI", [
      { type: "delta", text: "Last resort" },
      { type: "done" },
    ]);
    const { text } = await route(resolver({ gemini, groq, workersAI: workers }));
    await expect(text()).resolves.toBe(
      sse(ev.meta("lastResort", WORKERS_AI.model, false), ev.delta("Last resort"), ev.done()),
    );
    expect([gemini.calls.length, groq.calls.length, workers.calls.length]).toEqual([1, 1, 1]);
    // Every abandoned attempt was aborted, so its upstream request stops.
    expect(gemini.calls[0]?.signal.aborted).toBe(true);
    expect(groq.calls[0]?.signal.aborted).toBe(true);
  });

  it("uses the main candidate when it answers, with meta for that tier", async () => {
    const gemini = new Scripted("gemini", [{ type: "delta", text: "Main" }, { type: "done" }]);
    const groq = new Scripted("groq", [{ type: "delta", text: "never" }, { type: "done" }]);
    const { text } = await route(resolver({ gemini, groq }));
    await expect(text()).resolves.toBe(sse(ev.meta("main", GEMINI.model, true), ev.delta("Main"), ev.done()));
    expect(groq.calls).toHaveLength(0);
  });

  it("never fails over after the first delta", async () => {
    const gemini = new Scripted("gemini", [
      { type: "delta", text: "partial" },
      { type: "error", code: "upstream_unavailable" },
    ]);
    const groq = new Scripted("groq", [{ type: "delta", text: "never" }, { type: "done" }]);
    const { text } = await route(resolver({ gemini, groq }));
    await expect(text()).resolves.toBe(
      sse(ev.meta("main", GEMINI.model, true), ev.delta("partial"), ev.error("upstream_unavailable")),
    );
    expect(groq.calls).toHaveLength(0);
  });

  it("does not fail over on bad_request", async () => {
    const gemini = new Scripted("gemini", [{ type: "error", code: "bad_request" }]);
    const groq = new Scripted("groq", [{ type: "delta", text: "never" }, { type: "done" }]);
    const { text } = await route(resolver({ gemini, groq }));
    await expect(text()).resolves.toBe(ev.error("bad_request"));
    expect(groq.calls).toHaveLength(0);
  });

  it("fails over when a provider throws before output", async () => {
    const gemini = new Scripted("gemini", [{ type: "throw" }]);
    const groq = new Scripted("groq", [{ type: "delta", text: "ok" }, { type: "done" }]);
    const { text } = await route(resolver({ gemini, groq }));
    await expect(text()).resolves.toBe(sse(ev.meta("backup", GROQ.model, false), ev.delta("ok"), ev.done()));
  });

  it("returns the last attempt's error when every candidate fails", async () => {
    const gemini = new Scripted("gemini", [{ type: "error", code: "upstream_unavailable" }]);
    const groq = new Scripted("groq", [{ type: "error", code: "timeout" }]);
    const workers = new Scripted("workersAI", [{ type: "error", code: "rate_limited", retryAfter: 7 }]);
    const { text } = await route(resolver({ gemini, groq, workersAI: workers }));
    await expect(text()).resolves.toBe(ev.error("rate_limited", 7));
  });

  it("is upstream_unavailable when no candidate is configured", async () => {
    const { text } = await route(resolver({}));
    await expect(text()).resolves.toBe(ev.error("upstream_unavailable"));
  });
});

describe("router selection", () => {
  it("skips a candidate whose secret is missing (xAI optional) without spending its budget", async () => {
    const xai: Candidate = {
      ...GROQ,
      id: "xai-grok",
      provider: "xai",
      model: "grok-4",
      displayModel: "Grok",
    };
    const config: RoutingConfig = {
      ...routingConfig,
      tiers: { ...routingConfig.tiers, backup: [xai, GROQ] },
    };
    const env = envProviders({ GROQ_API_KEY: "groq-test-key" });
    expect(env(xai)).toBeNull();
    expect(env(GEMINI)).toBeNull();
    expect(env(GROQ)).not.toBeNull();

    const budgets = new DailyBudgets();
    const groq = new Scripted("groq", [{ type: "delta", text: "backup" }, { type: "done" }]);
    const providers: ProviderResolver = (c) => (c.provider === "groq" ? groq : env(c));
    const { text } = await route(providers, { config, budgets });
    await expect(text()).resolves.toBe(sse(ev.meta("backup", GROQ.model, false), ev.delta("backup"), ev.done()));
    expect(budgets.remaining(xai, T0)).toBe(xai.dailyBudget);
    expect(budgets.remaining(GROQ, T0)).toBe(GROQ.dailyBudget - 1);
  });

  it("treats a blank secret as missing", () => {
    const env = envProviders({ GEMINI_API_KEY: "   ", GROQ_API_KEY: "" });
    expect(env(GEMINI)).toBeNull();
    expect(env(GROQ)).toBeNull();
    expect(env(WORKERS_AI)).toBeNull();
  });

  it("skips a candidate with no budget left and charges one request per attempt", async () => {
    const budgets = new DailyBudgets();
    while (budgets.tryConsume(GEMINI, T0));
    const gemini = new Scripted("gemini", [{ type: "delta", text: "never" }, { type: "done" }]);
    const groq = new Scripted("groq", [{ type: "delta", text: "ok" }, { type: "done" }]);
    const { text } = await route(resolver({ gemini, groq }), { budgets });
    await expect(text()).resolves.toBe(sse(ev.meta("backup", GROQ.model, false), ev.delta("ok"), ev.done()));
    expect(gemini.calls).toHaveLength(0);
    expect(budgets.remaining(GROQ, T0)).toBe(GROQ.dailyBudget - 1);
  });

  it("is budget_exhausted when budgets are the only reason nothing ran", async () => {
    const budgets = new DailyBudgets();
    for (const c of orderedCandidates(routingConfig)) while (budgets.tryConsume(c, T0));
    const gemini = new Scripted("gemini", [{ type: "done" }]);
    const { text } = await route(resolver({ gemini }), { budgets });
    await expect(text()).resolves.toBe(ev.error("budget_exhausted"));
  });
});

describe("router timeouts and cancellation", () => {
  it("fails over when the first byte does not arrive in time, aborting the slow attempt", async () => {
    const gemini = new Scripted("gemini", [{ type: "delay", ms: 5_000 }, { type: "done" }]);
    const groq = new Scripted("groq", [{ type: "delta", text: "fast" }, { type: "done" }]);
    const { text } = await route(resolver({ gemini, groq }), { config: fastConfig() });
    await expect(text()).resolves.toBe(sse(ev.meta("backup", GROQ.model, false), ev.delta("fast"), ev.done()));
    expect(gemini.calls[0]?.signal.aborted).toBe(true);
  });

  it("closes with timeout when the stream goes idle after output (no failover)", async () => {
    const gemini = new Scripted("gemini", [
      { type: "delta", text: "half" },
      { type: "delay", ms: 5_000 },
      { type: "done" },
    ]);
    const groq = new Scripted("groq", [{ type: "delta", text: "never" }, { type: "done" }]);
    const { text } = await route(resolver({ gemini, groq }), { config: fastConfig() });
    await expect(text()).resolves.toBe(
      sse(ev.meta("main", GEMINI.model, true), ev.delta("half"), ev.error("timeout")),
    );
    expect(gemini.calls[0]?.signal.aborted).toBe(true);
    expect(groq.calls).toHaveLength(0);
  });

  it("aborts the upstream when the client cancels the response body", async () => {
    const gemini = new Scripted("gemini", [
      { type: "delta", text: "one" },
      { type: "delay", ms: 5_000 },
      { type: "done" },
    ]);
    const { opened } = await route(resolver({ gemini }), { config: fastConfig(1_000, 10_000) });
    expect(opened.ok).toBe(true);
    if (!opened.ok) return;
    const reader = opened.body.getReader();
    await reader.read();
    await reader.cancel();
    expect(gemini.calls[0]?.signal.aborted).toBe(true);
  });

  it("aborts the in-flight attempt and stops routing when the client signal aborts", async () => {
    const client = new AbortController();
    const gemini = new Scripted("gemini", [{ type: "delay", ms: 5_000 }, { type: "done" }]);
    const groq = new Scripted("groq", [{ type: "delta", text: "never" }, { type: "done" }]);
    const pending = route(resolver({ gemini, groq }), { signal: client.signal });
    await new Promise((resolve) => setTimeout(resolve, 10));
    client.abort();
    const { opened } = await pending;
    expect(opened.ok).toBe(false);
    expect(gemini.calls[0]?.signal.aborted).toBe(true);
    expect(groq.calls).toHaveLength(0);
  });

  it("withTimeouts passes chunks through untouched when they arrive in time", async () => {
    const provider = new FakeProvider({
      meta: { route: "x", model: "x", trainsOnPrompts: false },
      steps: [{ type: "delta", text: "a" }, { type: "delay", ms: 5 }, { type: "done" }],
    });
    const attempt = new AbortController();
    const chunks = [];
    for await (const chunk of withTimeouts(provider.stream({ request: REQUEST, signal: attempt.signal }), attempt, {
      firstByteMs: 500,
      idleMs: 500,
    })) {
      chunks.push(chunk);
    }
    expect(chunks).toEqual([{ type: "delta", text: "a" }, { type: "done" }]);
    expect(attempt.signal.aborted).toBe(false);
  });
});

describe("per-candidate redaction", () => {
  it("gives a trainsOnPrompts candidate minimal context: question + last 2 turns, no blocks", () => {
    const minimal = redactFor(REQUEST, GEMINI);
    expect(minimal.context).toEqual([]);
    expect(minimal.messages.map((m) => m.content)).toEqual([
      "You are Quicksilver.",
      "u4",
      "a4",
      "u5",
      "a5",
      "What now?",
    ]);
    expect(minimal.messages.filter((m) => m.role !== "system")).toHaveLength(MINIMAL_TURN_CAP * 2 + 1);
    expect(minimal.maxTokens).toBe(GEMINI.maxOutputTokens);
  });

  it("gives a standard candidate up to 4 turns and the context blocks", () => {
    const standard = redactFor(REQUEST, GROQ);
    expect(standard.messages.map((m) => m.content)).toEqual([
      "You are Quicksilver.",
      "u2",
      "a2",
      "u3",
      "a3",
      "u4",
      "a4",
      "u5",
      "a5",
      "What now?",
    ]);
    expect(standard.context.map((b) => b.kind)).toEqual(["memory", "device", "summary"]);
  });

  it("caps standard memory blocks at 3 and never mutates the input", () => {
    const many: ChatRequestV1 = {
      ...REQUEST,
      context: ["m1", "m2", "m3", "m4"].map((text) => ({ kind: "memory" as const, text, privacy: "device" as const })),
    };
    const before = JSON.stringify(many);
    expect(redactFor(many, GROQ).context.map((b) => b.text)).toEqual(["m1", "m2", "m3"]);
    expect(JSON.stringify(many)).toBe(before);
  });
});

describe("exact upstream payloads (real adapters, no network)", () => {
  interface Recorded {
    url: string;
    body: Record<string, unknown>;
  }

  /** Answers Gemini and Groq by URL; records every call. */
  function routedFetch(answers: { gemini: () => Response; groq: () => Response }) {
    const calls: Recorded[] = [];
    const fetch: FetchLike = async (url, init) => {
      calls.push({ url, body: JSON.parse(String(init.body)) as Record<string, unknown> });
      return url.includes("generativelanguage") ? answers.gemini() : answers.groq();
    };
    return { fetch, calls };
  }

  function workersBinding(respond: () => unknown) {
    const runs: { model: string; inputs: Record<string, unknown> }[] = [];
    const binding: WorkersAIBinding = {
      async run(model, inputs) {
        runs.push({ model, inputs });
        return respond();
      },
    };
    return { binding, runs };
  }

  const failing = () => new Response("unavailable", { status: 503 });
  const env = { GEMINI_API_KEY: "gemini-test-key", GROQ_API_KEY: "groq-test-key" };

  it("sends Gemini, as the first candidate, no memory/device/summary even when the app sent them", async () => {
    const { fetch, calls } = routedFetch({
      gemini: () => new Response(chunkedBody(geminiHappySse), { status: 200 }),
      groq: failing,
    });
    const { text } = await route(envProviders(env, fetch));
    await expect(text()).resolves.toContain(ev.meta("main", GEMINI.model, true));
    expect(calls).toHaveLength(1);

    const body = calls[0]?.body ?? {};
    expect(body).toEqual({
      contents: [
        { role: "user", parts: [{ text: "u4" }] },
        { role: "model", parts: [{ text: "a4" }] },
        { role: "user", parts: [{ text: "u5" }] },
        { role: "model", parts: [{ text: "a5" }] },
        { role: "user", parts: [{ text: "What now?" }] },
      ],
      systemInstruction: { parts: [{ text: "You are Quicksilver." }] },
      generationConfig: { maxOutputTokens: GEMINI.maxOutputTokens },
    });
    const raw = JSON.stringify(body);
    for (const leaked of [MEMORY, DEVICE, SUMMARY, "untrusted_notes", "u3", "a3"]) {
      expect(raw).not.toContain(leaked);
    }
  });

  it("sends Groq standard context after Gemini fails, and Workers AI the same after both fail", async () => {
    const { fetch, calls } = routedFetch({ gemini: failing, groq: failing });
    const { binding, runs } = workersBinding(() => chunkedBody(workersAIHappySse));
    const { text } = await route(envProviders({ ...env, AI: binding }, fetch));
    await expect(text()).resolves.toBe(
      sse(ev.meta("lastResort", WORKERS_AI.model, false), ev.delta("Quick"), ev.delta("silver."), "event: done\ndata: {\"usage\":{\"promptTokens\":28,\"completionTokens\":4}}\n\n"),
    );

    expect(calls.map((c) => (c.url.includes("generativelanguage") ? "gemini" : "groq"))).toEqual([
      "gemini",
      "groq",
    ]);
    const groqBody = calls[1]?.body ?? {};
    const groqMessages = groqBody.messages as { role: string; content: string }[];
    expect(groqBody.model).toBe(GROQ.model);
    expect(groqBody.max_completion_tokens).toBe(GROQ.maxOutputTokens);
    expect(groqMessages.map((m) => m.role)).toEqual([
      "system",
      "user", "assistant", "user", "assistant", "user", "assistant", "user", "assistant",
      "user",
    ]);
    expect(groqMessages[0]?.content).toContain(MEMORY);
    expect(groqMessages[0]?.content).toContain(DEVICE);
    expect(groqMessages[0]?.content).toContain(SUMMARY);
    expect(groqMessages[1]?.content).toBe("u2");

    expect(runs).toHaveLength(1);
    expect(runs[0]?.model).toBe(WORKERS_AI.model);
    const workersMessages = runs[0]?.inputs.messages as { role: string; content: string }[];
    expect(workersMessages).toEqual(groqMessages);
    expect(runs[0]?.inputs.max_tokens).toBe(WORKERS_AI.maxOutputTokens);
  });
});

describe("request validation", () => {
  const valid = JSON.parse(chatRequestJson) as Record<string, unknown>;

  it("accepts the protocol fixture", () => {
    expect(validateChatRequest(valid)).toEqual(valid);
  });

  it.each([
    ["not an object", []],
    ["missing messages", { ...valid, messages: undefined }],
    ["empty messages", { ...valid, messages: [] }],
    ["unknown role", { ...valid, messages: [{ role: "tool", content: "x" }] }],
    ["last turn not the user's", { ...valid, messages: [{ role: "user", content: "a" }, { role: "assistant", content: "b" }] }],
    ["non-string content", { ...valid, messages: [{ role: "user", content: 3 }] }],
    ["unknown context kind", { ...valid, context: [{ kind: "diagnostics", text: "x", privacy: "device" }] }],
    ["unknown privacy", { ...valid, privacy: "public" }],
    ["fractional maxTokens", { ...valid, maxTokens: 1.5 }],
    ["zero maxTokens", { ...valid, maxTokens: 0 }],
    ["missing context", { ...valid, context: undefined }],
    ["oversize content", { ...valid, messages: [{ role: "user", content: "x".repeat(16_001) }] }],
  ])("rejects %s", (_label, body) => {
    expect(validateChatRequest(body)).toBeNull();
  });

  it("drops unknown fields instead of forwarding them", () => {
    const parsed = validateChatRequest({ ...valid, extra: "nope", messages: [{ role: "user", content: "hi", name: "x" }] });
    expect(parsed).not.toBeNull();
    expect(JSON.stringify(parsed)).not.toContain("nope");
    expect(parsed?.messages).toEqual([{ role: "user", content: "hi" }]);
  });
});

describe("GET /v1/config", () => {
  const URL_CONFIG = "https://mercury-gateway.example/v1/config";
  const ENV = { DEVICE_TOKEN: TOKEN, GEMINI_API_KEY: "gemini-test-key" };

  function get(token?: string, method = "GET") {
    const headers = new Headers();
    if (token !== undefined) headers.set("authorization", `Bearer ${token}`);
    return new Request(URL_CONFIG, { method, headers });
  }

  it("returns the client-safe routing policy matching the protocol fixture", async () => {
    const response = await handleRequest(get(TOKEN), ENV, createState(), T0);
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    const text = await response.text();
    expect(JSON.parse(text)).toEqual(JSON.parse(configJson));
    expect(text).not.toMatch(/gemini-test-key|test-device-token|dailyBudget|api_?key/i);
  });

  it("requires the device token", async () => {
    const response = await handleRequest(get(), ENV, createState(), T0);
    expect(response.status).toBe(401);
    expect(response.headers.get("www-authenticate")).toBe("Bearer");
  });

  it("is GET only and rejects a query string", async () => {
    expect((await handleRequest(get(TOKEN, "POST"), ENV, createState(), T0)).status).toBe(405);
    const query = new Request(`${URL_CONFIG}?x=1`, { headers: { authorization: `Bearer ${TOKEN}` } });
    expect((await handleRequest(query, ENV, createState(), T0)).status).toBe(400);
  });

  it("marks any tier with a trainsOnPrompts candidate as minimal", () => {
    const config = clientConfig({
      ...routingConfig,
      tiers: { ...routingConfig.tiers, backup: [GROQ, { ...GROQ, id: "t", trainsOnPrompts: true }] },
    });
    expect(config.tiers.backup).toEqual({ displayModel: GROQ.displayModel, trainsOnPrompts: true, contextLevel: "minimal" });
  });
});

describe("routing.json timeouts", () => {
  it("fails over every candidate before the app's first-event timeout, and idles out before the app does", () => {
    const { firstByteMs, idleMs } = routingConfig.timeouts;
    expect(firstByteMs * orderedCandidates(routingConfig).length).toBeLessThan(CLIENT_TIMEOUTS.firstEvent * 1000);
    expect(idleMs).toBeLessThan(CLIENT_TIMEOUTS.idle * 1000);
  });

  it("caps every candidate's output tokens", () => {
    for (const c of orderedCandidates(routingConfig)) {
      expect(Number.isInteger(c.maxOutputTokens) && c.maxOutputTokens > 0).toBe(true);
      expect(c.displayModel.trim()).not.toBe("");
    }
  });
});

describe("POST /v1/chat through the router", () => {
  it("streams from the first healthy candidate", async () => {
    const gemini = new Scripted("gemini", [{ type: "error", code: "upstream_unavailable" }]);
    const groq = new Scripted("groq", [{ type: "delta", text: "Forge" }, { type: "done" }]);
    const state = createState(routingConfig, resolver({ gemini, groq }));
    const response = await handleRequest(
      new Request("https://mercury-gateway.example/v1/chat", {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${TOKEN}` },
        body: chatRequestJson,
      }),
      { DEVICE_TOKEN: TOKEN },
      state,
      T0,
    );
    expect(response.status).toBe(200);
    await expect(response.text()).resolves.toBe(sse(ev.meta("backup", GROQ.model, false), ev.delta("Forge"), ev.done()));
    // The fixture's memory/device blocks reach the standard candidate only.
    expect(gemini.calls[0]?.request.context).toEqual([]);
    expect(groq.calls[0]?.request.context.map((b) => b.kind)).toEqual(["memory", "device"]);
  });
});
