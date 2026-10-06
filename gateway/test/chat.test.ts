import { describe, expect, it } from "vitest";
import badRequestSse from "../fixtures/bad-request.sse?raw";
import budgetExhaustedSse from "../fixtures/budget-exhausted.sse?raw";
import chatRequestJson from "../fixtures/chat-request.json?raw";
import happySse from "../fixtures/happy.sse?raw";
import midStreamErrorSse from "../fixtures/mid-stream-error.sse?raw";
import unauthorizedSse from "../fixtures/unauthorized.sse?raw";
import upstreamUnavailableSse from "../fixtures/upstream-unavailable.sse?raw";
import { createState, handleRequest, type Env } from "../src/index";
import { orderedCandidates } from "../src/limits";

const TOKEN = "test-device-token-not-a-secret";
const ENV: Env = { DEVICE_TOKEN: TOKEN };
const URL_CHAT = "https://mercury-gateway.example/v1/chat";
const T0 = Date.parse("2026-10-05T12:00:00.000Z");

function chat(token?: string, method = "POST", url = URL_CHAT): Request {
  const headers = new Headers({ "content-type": "application/json" });
  if (token !== undefined) headers.set("authorization", `Bearer ${token}`);
  return new Request(url, { method, headers, body: method === "POST" ? chatRequestJson : undefined });
}

describe("POST /v1/chat auth", () => {
  it("returns 401 + unauthorized event when the token is missing", async () => {
    const response = await handleRequest(chat(), ENV, createState(), T0);
    expect(response.status).toBe(401);
    expect(response.headers.get("www-authenticate")).toBe("Bearer");
    expect(response.headers.get("content-type")).toMatch(/^text\/event-stream/);
    await expect(response.text()).resolves.toBe(unauthorizedSse);
  });

  it("returns 401 for a wrong token", async () => {
    const response = await handleRequest(chat("wrong"), ENV, createState(), T0);
    expect(response.status).toBe(401);
    await expect(response.text()).resolves.toBe(unauthorizedSse);
  });

  it("fails closed when DEVICE_TOKEN is not configured", async () => {
    const response = await handleRequest(chat(TOKEN), {}, createState(), T0);
    expect(response.status).toBe(401);
  });

  it("admits the right token (no provider secrets set -> upstream_unavailable)", async () => {
    const response = await handleRequest(chat(TOKEN), ENV, createState(), T0);
    expect(response.status).toBe(200);
    await expect(response.text()).resolves.toBe(upstreamUnavailableSse);
  });

  it("keeps the URL policy: query is 400 before auth, GET is 405", async () => {
    const query = await handleRequest(
      chat(TOKEN, "POST", `${URL_CHAT}?token=${TOKEN}`),
      ENV,
      createState(),
      T0,
    );
    expect(query.status).toBe(400);
    const get = await handleRequest(chat(TOKEN, "GET"), ENV, createState(), T0);
    expect(get.status).toBe(405);
  });
});

describe("POST /v1/chat limits", () => {
  it("rate-limits a token past its RPM with a typed rate_limited event", async () => {
    const state = createState();
    for (let i = 0; i < state.config.rpmPerToken; i += 1) {
      const ok = await handleRequest(chat(TOKEN), ENV, state, T0);
      expect(ok.status).toBe(200);
    }
    const limited = await handleRequest(chat(TOKEN), ENV, state, T0 + 15_000);
    expect(limited.status).toBe(429);
    expect(limited.headers.get("retry-after")).toBe("45");
    await expect(limited.text()).resolves.toBe(
      'event: error\ndata: {"code":"rate_limited","retryAfter":45}\n\n',
    );
  });

  it("does not count unauthorized requests against the RPM limit", async () => {
    const state = createState();
    for (let i = 0; i < state.config.rpmPerToken + 5; i += 1) {
      await handleRequest(chat("wrong"), ENV, state, T0);
    }
    const response = await handleRequest(chat(TOKEN), ENV, state, T0);
    expect(response.status).toBe(200);
  });

  it("returns budget_exhausted once every candidate's daily budget is spent, and resets next UTC day", async () => {
    const state = createState();
    for (const candidate of orderedCandidates(state.config)) {
      while (state.budgets.tryConsume(candidate, T0));
    }
    const exhausted = await handleRequest(chat(TOKEN), ENV, state, T0);
    expect(exhausted.status).toBe(200);
    await expect(exhausted.text()).resolves.toBe(budgetExhaustedSse);

    const nextDay = Date.parse("2026-10-06T00:00:00.000Z");
    const reset = await handleRequest(chat(TOKEN), ENV, state, nextDay);
    await expect(reset.text()).resolves.toBe(upstreamUnavailableSse);
  });

  it("keeps serving while any candidate has budget left", async () => {
    const state = createState();
    const [main] = orderedCandidates(state.config);
    while (state.budgets.tryConsume(main, T0));
    const response = await handleRequest(chat(TOKEN), ENV, state, T0);
    await expect(response.text()).resolves.toBe(upstreamUnavailableSse);
  });
});

describe("POST /v1/chat FAKE_MODE (local dev only)", () => {
  function chatWithBody(body: string): Request {
    return new Request(URL_CHAT, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${TOKEN}` },
      body,
    });
  }

  it("streams the happy fixture when FAKE_MODE=1", async () => {
    const response = await handleRequest(
      chatWithBody(chatRequestJson),
      { ...ENV, FAKE_MODE: "1" },
      createState(),
      T0,
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toMatch(/^text\/event-stream/);
    await expect(response.text()).resolves.toBe(happySse);
  });

  it("runs a named script", async () => {
    const response = await handleRequest(
      chatWithBody(chatRequestJson),
      { ...ENV, FAKE_MODE: "mid-stream-error" },
      createState(),
      T0,
    );
    await expect(response.text()).resolves.toBe(midStreamErrorSse);
  });

  it("stays off for an unknown FAKE_MODE value", async () => {
    const response = await handleRequest(
      chatWithBody(chatRequestJson),
      { ...ENV, FAKE_MODE: "yes please" },
      createState(),
      T0,
    );
    await expect(response.text()).resolves.toBe(upstreamUnavailableSse);
  });

  it("still requires the device token", async () => {
    const response = await handleRequest(chat(), { ...ENV, FAKE_MODE: "1" }, createState(), T0);
    expect(response.status).toBe(401);
    await expect(response.text()).resolves.toBe(unauthorizedSse);
  });

  it("rejects a non-object JSON body with bad_request", async () => {
    const response = await handleRequest(
      chatWithBody("not json"),
      { ...ENV, FAKE_MODE: "1" },
      createState(),
      T0,
    );
    expect(response.status).toBe(400);
    await expect(response.text()).resolves.toBe(badRequestSse);
  });
});
