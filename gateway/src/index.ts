/**
 * Mercury Gateway Worker.
 * M3-T15: health endpoint. M3-T16: device-token auth, per-token RPM limit, and
 * per-candidate daily budgets on `POST /v1/chat`. M3-T17: protocol v1 stream layer
 * (src/stream.ts) and a deterministic fake upstream behind local `FAKE_MODE`. M3-T18:
 * Gemini + OpenAI-compatible adapters (src/providers/), not wired here yet. The router
 * (M3-T20) wires them in; until then an admitted chat request gets
 * `upstream_unavailable` (or the fake stream when `FAKE_MODE` names a script).
 *
 * Privacy: never log request or response bodies or tokens — Workers Logs stay metadata-only.
 * Route policy: query, fragment, and userinfo are rejected so a device token cannot ride
 * in the URL. Unknown paths are 404 and are not echoed.
 */

import { authenticate } from "./auth";
import {
  DailyBudgets,
  RpmLimiter,
  firstCandidateWithBudget,
  routingConfig,
  type RoutingConfig,
} from "./limits";
import { FAKE_SCRIPTS, FakeProvider, fakeScenario } from "./providers/fake";
import { errorResponse, openV1Stream, streamResponse, type ChatRequestV1 } from "./stream";

export interface Env {
  /** Worker secret set by Christopher at HG3 (`wrangler secret put DEVICE_TOKEN`). */
  DEVICE_TOKEN?: string;
  /**
   * Local development only (`.dev.vars`, never a deployed var): names a script in
   * `FAKE_SCRIPTS` (`1` / `true` = `happy`) so admitted chats stream from the fake.
   */
  FAKE_MODE?: string;
}

/** In-isolate limiter state (best-effort; see limits.ts). */
export interface GatewayState {
  config: RoutingConfig;
  rpm: RpmLimiter;
  budgets: DailyBudgets;
}

export function createState(config: RoutingConfig = routingConfig): GatewayState {
  return {
    config,
    rpm: new RpmLimiter(config.rpmPerToken),
    budgets: new DailyBudgets(),
  };
}

const defaultState = createState();

const HEALTH_PATH = "/v1/health";
const CHAT_PATH = "/v1/chat";

function plain(status: number, body: string): Response {
  return new Response(body, {
    status,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

/** Parses the JSON body as an object; full validation lands with the router (M3-T20). */
async function readChatBody(request: Request): Promise<ChatRequestV1 | null> {
  try {
    const body: unknown = await request.json();
    return typeof body === "object" && body !== null && !Array.isArray(body)
      ? (body as ChatRequestV1)
      : null;
  } catch {
    return null;
  }
}

async function handleChat(request: Request, env: Env, state: GatewayState, now: number) {
  const auth = await authenticate(request, env.DEVICE_TOKEN);
  if (!auth.ok) {
    return errorResponse(401, { code: "unauthorized" }, { "www-authenticate": "Bearer" });
  }

  const rate = state.rpm.check(auth.tokenKey, now);
  if (!rate.ok) {
    return errorResponse(
      429,
      { code: "rate_limited", retryAfter: rate.retryAfter },
      { "retry-after": String(rate.retryAfter) },
    );
  }

  // 200 + typed error event: the app reads it and goes on-device.
  if (firstCandidateWithBudget(state.config, state.budgets, now) === null) {
    return errorResponse(200, { code: "budget_exhausted" });
  }

  const scenario = fakeScenario(env.FAKE_MODE);
  if (scenario !== null) {
    const body = await readChatBody(request);
    if (body === null) return errorResponse(400, { code: "bad_request" });
    const provider = new FakeProvider(FAKE_SCRIPTS[scenario]);
    const abort = new AbortController();
    const opened = await openV1Stream(
      provider.meta,
      provider.stream({ request: body, signal: abort.signal }),
      { abort },
    );
    return streamResponse(opened);
  }

  // The Gemini and OpenAI-compatible adapters (M3-T18) exist but are not wired into
  // POST /v1/chat until the router lands (M3-T20). The router will call
  // `state.budgets.tryConsume(candidate, now)` before each upstream attempt.
  return errorResponse(200, { code: "upstream_unavailable" });
}

/** Exported for unit tests (no network). */
export async function handleRequest(
  request: Request,
  env: Env = {},
  state: GatewayState = defaultState,
  now: number = Date.now(),
): Promise<Response> {
  let url: URL;
  try {
    url = new URL(request.url);
  } catch {
    return plain(400, "Bad Request");
  }

  if (url.username || url.password) {
    return plain(400, "Bad Request");
  }

  if (url.pathname !== HEALTH_PATH && url.pathname !== CHAT_PATH) {
    return plain(404, "Not Found");
  }

  if (url.search || url.hash) {
    return plain(400, "Bad Request");
  }

  if (url.pathname === CHAT_PATH) {
    if (request.method !== "POST") {
      return plain(405, "Method Not Allowed");
    }
    return handleChat(request, env, state, now);
  }

  if (request.method !== "GET") {
    return plain(405, "Method Not Allowed");
  }

  return Response.json(
    { ok: true, service: "mercury-gateway" },
    {
      status: 200,
      headers: { "cache-control": "no-store" },
    },
  );
}

export default {
  async fetch(
    request: Request,
    env: Env,
    _ctx: ExecutionContext,
  ): Promise<Response> {
    return handleRequest(request, env);
  },
};
