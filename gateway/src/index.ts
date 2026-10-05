/**
 * Mercury Gateway Worker.
 * M3-T15: health endpoint. M3-T16: device-token auth, per-token RPM limit, and
 * per-candidate daily budgets on `POST /v1/chat`. Streaming, providers, and the router
 * land in M3-T17..T20; until then an admitted chat request gets `upstream_unavailable`.
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

export interface Env {
  /** Worker secret set by Christopher at HG3 (`wrangler secret put DEVICE_TOKEN`). */
  DEVICE_TOKEN?: string;
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

type ErrorCode = "unauthorized" | "rate_limited" | "budget_exhausted" | "upstream_unavailable";

/** A single protocol v1 `error` event (same bytes as gateway/fixtures/*.sse). */
function sseError(
  status: number,
  code: ErrorCode,
  extra: { retryAfter?: number; headers?: Record<string, string> } = {},
): Response {
  const data = extra.retryAfter === undefined ? { code } : { code, retryAfter: extra.retryAfter };
  return new Response(`event: error\ndata: ${JSON.stringify(data)}\n\n`, {
    status,
    headers: {
      "content-type": "text/event-stream; charset=utf-8",
      "cache-control": "no-store",
      ...extra.headers,
    },
  });
}

async function handleChat(request: Request, env: Env, state: GatewayState, now: number) {
  const auth = await authenticate(request, env.DEVICE_TOKEN);
  if (!auth.ok) {
    return sseError(401, "unauthorized", { headers: { "www-authenticate": "Bearer" } });
  }

  const rate = state.rpm.check(auth.tokenKey, now);
  if (!rate.ok) {
    return sseError(429, "rate_limited", {
      retryAfter: rate.retryAfter,
      headers: { "retry-after": String(rate.retryAfter) },
    });
  }

  // 200 + typed error event: the app reads it and goes on-device.
  if (firstCandidateWithBudget(state.config, state.budgets, now) === null) {
    return sseError(200, "budget_exhausted");
  }

  // No provider adapters yet (M3-T17..T20). The router will call
  // `state.budgets.tryConsume(candidate, now)` before each upstream attempt.
  return sseError(200, "upstream_unavailable");
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
