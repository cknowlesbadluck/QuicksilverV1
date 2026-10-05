import { describe, expect, it } from "vitest";
import badRequestSse from "../fixtures/bad-request.sse?raw";
import budgetExhaustedSse from "../fixtures/budget-exhausted.sse?raw";
import happySse from "../fixtures/happy.sse?raw";
import midStreamErrorSse from "../fixtures/mid-stream-error.sse?raw";
import rateLimitedSse from "../fixtures/rate-limited.sse?raw";
import timeoutSse from "../fixtures/timeout.sse?raw";
import unauthorizedSse from "../fixtures/unauthorized.sse?raw";
import upstreamUnavailableSse from "../fixtures/upstream-unavailable.sse?raw";
import { FAKE_SCRIPTS, FakeProvider, type FakeScenario, type FakeScript } from "../src/providers/fake";
import {
  encodeEvent,
  normalizeError,
  openV1Stream,
  streamResponse,
  type ChatRequestV1,
  type Meta,
  type ProviderChunk,
} from "../src/stream";

const REQUEST: ChatRequestV1 = {
  taskTier: "standard",
  messages: [{ role: "user", content: "Name the active aspect." }],
  context: [],
  privacy: "device",
  maxTokens: 64,
};
const META: Meta = { route: "cloud", model: "fake", trainsOnPrompts: true };

async function runScript(script: FakeScript, abort = new AbortController()): Promise<string> {
  const provider = new FakeProvider(script);
  const opened = await openV1Stream(
    provider.meta,
    provider.stream({ request: REQUEST, signal: abort.signal }),
    { abort },
  );
  return streamResponse(opened).text();
}

async function* fromChunks(chunks: ProviderChunk[], thenThrow = false): AsyncGenerator<ProviderChunk> {
  for (const chunk of chunks) yield chunk;
  if (thenThrow) throw new Error("dropped");
}

describe("fixture parity (fake upstream -> protocol v1 bytes)", () => {
  const cases: [FakeScenario, string][] = [
    ["happy", happySse],
    ["mid-stream-error", midStreamErrorSse],
    ["rate-limited", rateLimitedSse],
    ["timeout", timeoutSse],
    ["upstream-unavailable", upstreamUnavailableSse],
    ["budget-exhausted", budgetExhaustedSse],
    ["bad-request", badRequestSse],
    ["unauthorized", unauthorizedSse],
  ];

  it("has one script per stream fixture", () => {
    expect(Object.keys(FAKE_SCRIPTS).sort()).toEqual(cases.map(([name]) => name).sort());
  });

  for (const [scenario, fixture] of cases) {
    it(`${scenario} matches gateway/fixtures/${scenario}.sse byte for byte`, async () => {
      await expect(runScript(FAKE_SCRIPTS[scenario])).resolves.toBe(fixture);
    });
  }

  it("is deterministic across runs", async () => {
    const first = await runScript(FAKE_SCRIPTS.happy);
    const second = await runScript(FAKE_SCRIPTS.happy);
    expect(second).toBe(first);
  });

  it("serves the stream as no-store text/event-stream", async () => {
    const provider = new FakeProvider(FAKE_SCRIPTS.happy);
    const abort = new AbortController();
    const response = streamResponse(
      await openV1Stream(provider.meta, provider.stream({ request: REQUEST, signal: abort.signal })),
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("text/event-stream; charset=utf-8");
    expect(response.headers.get("cache-control")).toBe("no-store");
  });
});

describe("stream grammar", () => {
  it("reports an error before output as ok:false with no meta sent", async () => {
    const opened = await openV1Stream(META, fromChunks([{ type: "error", code: "timeout" }]));
    expect(opened).toEqual({ ok: false, error: { code: "timeout" } });
  });

  it("treats a throw before output as upstream_unavailable", async () => {
    const opened = await openV1Stream(META, fromChunks([], true));
    expect(opened).toEqual({ ok: false, error: { code: "upstream_unavailable" } });
  });

  it("treats an empty upstream as upstream_unavailable", async () => {
    const opened = await openV1Stream(META, fromChunks([]));
    expect(opened).toEqual({ ok: false, error: { code: "upstream_unavailable" } });
  });

  it("closes a throw after output with a typed error and keeps the partial text", async () => {
    const opened = await openV1Stream(META, fromChunks([{ type: "delta", text: "partial" }], true));
    await expect(streamResponse(opened).text()).resolves.toBe(midStreamErrorSse);
  });

  it("closes an upstream that ends without done or error", async () => {
    const opened = await openV1Stream(META, fromChunks([{ type: "delta", text: "partial" }]));
    await expect(streamResponse(opened).text()).resolves.toBe(midStreamErrorSse);
  });

  it("drops empty deltas and stops at the first terminal chunk", async () => {
    const opened = await openV1Stream(
      META,
      fromChunks([
        { type: "delta", text: "" },
        { type: "delta", text: "a" },
        { type: "done" },
        { type: "delta", text: "ignored" },
      ]),
    );
    await expect(streamResponse(opened).text()).resolves.toBe(
      encodeEvent({ event: "meta", data: META }) +
        'event: delta\ndata: {"text":"a"}\n\n' +
        "event: done\ndata: {}\n\n",
    );
  });

  it("releases the upstream as soon as a terminal chunk arrives", async () => {
    let released = false;
    async function* upstream(): AsyncGenerator<ProviderChunk> {
      try {
        yield { type: "delta", text: "a" };
        yield { type: "done" };
        yield { type: "delta", text: "never read" };
      } finally {
        released = true;
      }
    }
    const opened = await openV1Stream(META, upstream());
    await streamResponse(opened).text();
    expect(released).toBe(true);
  });

  it("writes integral numbers only", () => {
    expect(normalizeError("rate_limited", 1.2)).toEqual({ code: "rate_limited", retryAfter: 2 });
    expect(normalizeError("rate_limited")).toEqual({ code: "rate_limited", retryAfter: 1 });
    expect(normalizeError("timeout", Number.NaN)).toEqual({ code: "timeout" });
    expect(
      encodeEvent({ event: "done", data: { usage: { promptTokens: 3.5, completionTokens: -1 } } }),
    ).toBe("event: done\ndata: {}\n\n");
  });
});

describe("fake upstream delays and abort", () => {
  it("honours scripted delays", async () => {
    const started = Date.now();
    const text = await runScript({
      meta: META,
      steps: [
        { type: "delay", ms: 40 },
        { type: "delta", text: "late" },
        { type: "done" },
      ],
    });
    expect(Date.now() - started).toBeGreaterThanOrEqual(35);
    expect(text).toContain('data: {"text":"late"}');
  });

  it("a delay before output that is aborted surfaces as upstream_unavailable", async () => {
    const abort = new AbortController();
    const provider = new FakeProvider({ meta: META, steps: [{ type: "delay", ms: 10_000 }] });
    const pending = openV1Stream(provider.meta, provider.stream({ request: REQUEST, signal: abort.signal }), {
      abort,
    });
    abort.abort();
    await expect(pending).resolves.toEqual({ ok: false, error: { code: "upstream_unavailable" } });
  });

  it("cancelling the client stream aborts the upstream promptly", async () => {
    const abort = new AbortController();
    const provider = new FakeProvider({
      meta: META,
      steps: [
        { type: "delta", text: "first" },
        { type: "delay", ms: 10_000 },
        { type: "done" },
      ],
    });
    const opened = await openV1Stream(
      provider.meta,
      provider.stream({ request: REQUEST, signal: abort.signal }),
      { abort },
    );
    if (!opened.ok) throw new Error("expected an open stream");
    const reader = opened.body.getReader();
    await reader.read(); // meta
    await reader.read(); // first delta
    const started = Date.now();
    await reader.cancel();
    expect(abort.signal.aborted).toBe(true);
    expect(Date.now() - started).toBeLessThan(1_000);
  });

  it("a scripted throw after output becomes a typed error", async () => {
    const text = await runScript({
      meta: META,
      steps: [{ type: "delta", text: "partial" }, { type: "throw" }],
    });
    expect(text).toBe(midStreamErrorSse);
  });
});
