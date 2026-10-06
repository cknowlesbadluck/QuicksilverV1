/**
 * Mercury Gateway Worker.
 * M3-T15: health endpoint. M3-T16: device-token auth, per-token RPM limit, and
 * per-candidate daily budgets on `POST /v1/chat`. M3-T17: protocol v1 stream layer
 * (src/stream.ts) and a deterministic fake upstream behind local `FAKE_MODE`. M3-T18:
 * Gemini + OpenAI-compatible adapters (src/providers/). M3-T19: Workers AI adapter over
 * the free `env.AI` binding. M3-T20: the router (src/router.ts) validates the body, picks
 * a candidate per `config/routing.json`, redacts per candidate, fails over before the
 * first delta, and serves the client-safe `GET /v1/config`. Local `FAKE_MODE` still
 * replaces every upstream with the deterministic fake.
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
import {
  clientConfig,
  envProviders,
  routeChat,
  validateChatRequest,
  type ProviderEnv,
  type ProviderResolver,
} from "./router";
import { errorResponse, openV1Stream, streamResponse, type ChatRequestV1 } from "./stream";

/** Secrets: `DEVICE_TOKEN`, `GEMINI_API_KEY`, `GROQ_API_KEY`, optional `XAI_API_KEY` (HG3). */
export interface Env extends ProviderEnv {
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
  /** Test seam: replaces the env-backed adapters (`envProviders`). */
  providers?: ProviderResolver;
}

export function createState(
  config: RoutingConfig = routingConfig,
  providers?: ProviderResolver,
): GatewayState {
  return {
    config,
    rpm: new RpmLimiter(config.rpmPerToken),
    budgets: new DailyBudgets(),
    providers,
  };
}

const defaultState = createState();

const HEALTH_PATH = "/v1/health";
const CHAT_PATH = "/v1/chat";
const CONFIG_PATH = "/v1/config";
const ROUTES = new Set([HEALTH_PATH, CHAT_PATH, CONFIG_PATH]);

function plain(status: number, body: string): Response {
  return new Response(body, {
    status,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

/** Parses and validates the JSON body (protocol v1); null means `bad_request`. */
async function readChatBody(request: Request): Promise<ChatRequestV1 | null> {
  try {
    return validateChatRequest(await request.json());
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

  const body = await readChatBody(request);
  if (body === null) return errorResponse(400, { code: "bad_request" });

  const scenario = fakeScenario(env.FAKE_MODE);
  if (scenario !== null) {
    const provider = new FakeProvider(FAKE_SCRIPTS[scenario]);
    const abort = new AbortController();
    const opened = await openV1Stream(
      provider.meta,
      provider.stream({ request: body, signal: abort.signal }),
      { abort },
    );
    return streamResponse(opened);
  }

  const opened = await routeChat(body, {
    config: state.config,
    budgets: state.budgets,
    providers: state.providers ?? envProviders(env),
    now,
    signal: request.signal,
  });
  return streamResponse(opened);
}

/** `GET /v1/config`: device token required; client-safe routing only (no keys, budgets). */
async function handleConfig(request: Request, env: Env, state: GatewayState): Promise<Response> {
  const auth = await authenticate(request, env.DEVICE_TOKEN);
  if (!auth.ok) {
    return errorResponse(401, { code: "unauthorized" }, { "www-authenticate": "Bearer" });
  }
  return Response.json(clientConfig(state.config), {
    status: 200,
    headers: { "cache-control": "no-store" },
  });
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

  if (!ROUTES.has(url.pathname)) {
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

  if (url.pathname === CONFIG_PATH) {
    return handleConfig(request, env, state);
  }

  return Response.json(
    { ok: true, service: "mercury-gateway", contractRevision: "2026-10-06-eval-landed" },
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
