import { describe, expect, it } from "vitest";
import blockedSse from "../fixtures/upstream/gemini-blocked.sse?raw";
import happySse from "../fixtures/upstream/gemini-happy.sse?raw";
import invalidKeyJson from "../fixtures/upstream/gemini-invalid-key.json?raw";
import rateLimitedJson from "../fixtures/upstream/gemini-rate-limited.json?raw";
import safetySse from "../fixtures/upstream/gemini-safety-mid-stream.sse?raw";
import thoughtSse from "../fixtures/upstream/gemini-thought.sse?raw";
import { GEMINI_BASE_URL, GeminiProvider } from "../src/providers/gemini";
import { encodeEvent, type ChatRequestV1, type ProviderChunk } from "../src/stream";
import { META, fakeFetch, sse, sseResponse, v1Text } from "./upstreamHelpers";

const REQUEST: ChatRequestV1 = {
  taskTier: "standard",
  messages: [
    { role: "system", content: "You are Quicksilver." },
    { role: "user", content: "What aspect is active?" },
    { role: "assistant", content: "Forge." },
    { role: "user", content: "Name one Forge strength." },
  ],
  context: [],
  privacy: "device",
  maxTokens: 128,
};

const KEY = "test-gemini-key";

function provider(fetch: ReturnType<typeof fakeFetch>["fetch"], key: { apiKey: string | undefined } = { apiKey: KEY }) {
  return new GeminiProvider({ apiKey: key.apiKey, model: "gemini-3.7-flash", fetch });
}

async function chunks(p: GeminiProvider, request = REQUEST): Promise<ProviderChunk[]> {
  const out: ProviderChunk[] = [];
  for await (const chunk of p.stream({ request, signal: new AbortController().signal })) out.push(chunk);
  return out;
}

describe("GeminiProvider request", () => {
  it("streams via streamGenerateContent?alt=sse with the key only in x-goog-api-key", async () => {
    const recorder = fakeFetch(() => sseResponse(happySse));
    await chunks(provider(recorder.fetch));
    expect(recorder.calls).toHaveLength(1);
    const [call] = recorder.calls;
    expect(call?.url).toBe(`${GEMINI_BASE_URL}/models/gemini-3.7-flash:streamGenerateContent?alt=sse`);
    expect(call?.url).not.toContain(KEY);
    expect(call?.init.method).toBe("POST");
    expect(call?.headers["x-goog-api-key"]).toBe(KEY);
    expect(call?.headers.authorization).toBeUndefined();
    expect(call?.body).toEqual({
      contents: [
        { role: "user", parts: [{ text: "What aspect is active?" }] },
        { role: "model", parts: [{ text: "Forge." }] },
        { role: "user", parts: [{ text: "Name one Forge strength." }] },
      ],
      systemInstruction: { parts: [{ text: "You are Quicksilver." }] },
      generationConfig: { maxOutputTokens: 128 },
    });
  });

  it("passes the abort signal to fetch", async () => {
    const recorder = fakeFetch(() => sseResponse(happySse));
    const abort = new AbortController();
    for await (const _ of provider(recorder.fetch).stream({ request: REQUEST, signal: abort.signal })) {
      // drain
    }
    expect(recorder.calls[0]?.init.signal).toBe(abort.signal);
  });

  it("is unavailable without a key and never calls the network", async () => {
    const recorder = fakeFetch(() => sseResponse(happySse));
    await expect(chunks(provider(recorder.fetch, { apiKey: undefined }))).resolves.toEqual([
      { type: "error", code: "upstream_unavailable" },
    ]);
    await expect(chunks(provider(recorder.fetch, { apiKey: "  " }))).resolves.toEqual([
      { type: "error", code: "upstream_unavailable" },
    ]);
    expect(recorder.calls).toHaveLength(0);
  });

  it("rejects an unanswerable request as bad_request without calling the network", async () => {
    const recorder = fakeFetch(() => sseResponse(happySse));
    await expect(chunks(provider(recorder.fetch), { ...REQUEST, messages: [] })).resolves.toEqual([
      { type: "error", code: "bad_request" },
    ]);
    expect(recorder.calls).toHaveLength(0);
  });
});

describe("GeminiProvider stream mapping (recorded-format fixtures -> protocol v1)", () => {
  it("maps text parts to deltas and STOP to done with usage", async () => {
    const recorder = fakeFetch(() => sseResponse(happySse));
    await expect(v1Text(provider(recorder.fetch), REQUEST)).resolves.toBe(
      sse(
        encodeEvent({ event: "meta", data: META }),
        encodeEvent({ event: "delta", data: { text: "Forge " } }),
        encodeEvent({ event: "delta", data: { text: "is " } }),
        encodeEvent({ event: "delta", data: { text: "awake." } }),
        encodeEvent({ event: "done", data: { usage: { promptTokens: 21, completionTokens: 3 } } }),
      ),
    );
  });

  it("skips thought parts, accepts CRLF framing and treats MAX_TOKENS as done", async () => {
    const crlf = thoughtSse.replaceAll("\n", "\r\n");
    const recorder = fakeFetch(() => sseResponse(crlf));
    await expect(chunks(provider(recorder.fetch))).resolves.toEqual([
      { type: "delta", text: "Eternal." },
      { type: "done", usage: { promptTokens: 9, completionTokens: 2 } },
    ]);
  });

  it("maps a blocked prompt to bad_request before any output", async () => {
    const recorder = fakeFetch(() => sseResponse(blockedSse));
    await expect(v1Text(provider(recorder.fetch), REQUEST)).resolves.toBe(
      encodeEvent({ event: "error", data: { code: "bad_request" } }),
    );
  });

  it("keeps partial text and ends with an error on a SAFETY stop mid-stream", async () => {
    const recorder = fakeFetch(() => sseResponse(safetySse));
    await expect(v1Text(provider(recorder.fetch), REQUEST)).resolves.toBe(
      sse(
        encodeEvent({ event: "meta", data: META }),
        encodeEvent({ event: "delta", data: { text: "Here is" } }),
        encodeEvent({ event: "error", data: { code: "bad_request" } }),
      ),
    );
  });

  it("reports a stream that ends without a finish reason as incomplete", async () => {
    const truncated = happySse.split("\n\n").slice(0, 2).join("\n\n") + "\n\n";
    const recorder = fakeFetch(() => sseResponse(truncated));
    const text = await v1Text(provider(recorder.fetch), REQUEST);
    expect(text.endsWith(encodeEvent({ event: "error", data: { code: "upstream_unavailable" } }))).toBe(true);
  });

  it("maps an in-stream error object and malformed JSON to upstream_unavailable", async () => {
    for (const body of ['data: {"error":{"code":503,"status":"UNAVAILABLE"}}\n\n', "data: {not json\n\n"]) {
      const recorder = fakeFetch(() => sseResponse(body));
      await expect(chunks(provider(recorder.fetch))).resolves.toEqual([
        { type: "error", code: "upstream_unavailable" },
      ]);
    }
  });
});

describe("GeminiProvider HTTP failures", () => {
  function status(code: number, body = "{}", headers: Record<string, string> = {}) {
    return fakeFetch(() => new Response(body, { status: code, headers }));
  }

  it("429 carries Retry-After, else Gemini's RetryInfo delay", async () => {
    await expect(chunks(provider(status(429, rateLimitedJson, { "retry-after": "4" }).fetch))).resolves.toEqual([
      { type: "error", code: "rate_limited", retryAfter: 4 },
    ]);
    await expect(chunks(provider(status(429, rateLimitedJson).fetch))).resolves.toEqual([
      { type: "error", code: "rate_limited", retryAfter: 18 },
    ]);
    // No delay anywhere: the stream layer floors rate_limited at 1 s.
    await expect(v1Text(provider(status(429).fetch), REQUEST)).resolves.toBe(
      encodeEvent({ event: "error", data: { code: "rate_limited", retryAfter: 1 } }),
    );
  });

  it("401/403 and an invalid key are upstream_unavailable (the gateway's key), so the router can fail over", async () => {
    for (const code of [401, 403]) {
      await expect(chunks(provider(status(code).fetch))).resolves.toEqual([
        { type: "error", code: "upstream_unavailable" },
      ]);
    }
    await expect(chunks(provider(status(400, invalidKeyJson).fetch))).resolves.toEqual([
      { type: "error", code: "upstream_unavailable" },
    ]);
  });

  it("other 400s are bad_request; 5xx are upstream_unavailable; 504 is timeout", async () => {
    await expect(chunks(provider(status(400, '{"error":{"status":"INVALID_ARGUMENT"}}').fetch))).resolves.toEqual([
      { type: "error", code: "bad_request" },
    ]);
    await expect(chunks(provider(status(503).fetch))).resolves.toEqual([
      { type: "error", code: "upstream_unavailable" },
    ]);
    await expect(chunks(provider(status(504).fetch))).resolves.toEqual([{ type: "error", code: "timeout" }]);
  });

  it("a network failure is upstream_unavailable; an abort rethrows instead of reporting", async () => {
    const failing = provider(async () => {
      throw new TypeError("network down");
    });
    await expect(chunks(failing)).resolves.toEqual([{ type: "error", code: "upstream_unavailable" }]);

    const abort = new AbortController();
    abort.abort();
    const aborted = provider(async () => {
      throw new DOMException("aborted", "AbortError");
    });
    const iterate = async () => {
      for await (const _ of aborted.stream({ request: REQUEST, signal: abort.signal })) {
        // unreachable
      }
    };
    await expect(iterate()).rejects.toThrow("aborted");
  });
});
