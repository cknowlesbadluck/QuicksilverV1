/**
 * Mercury Gateway Worker (scaffold).
 * M3-T15: health endpoint only. Auth, streaming, and providers land in later M3 tasks.
 *
 * Privacy: never log request or response bodies — Workers Logs stay metadata-only.
 * Route policy: GET /v1/health only. Query, fragment, and userinfo are rejected so a
 * device token cannot ride in the URL. Unknown paths are 404 and are not echoed.
 */

export interface Env {
  // Secrets and bindings arrive in M3-T16+ / HG3. Scaffold intentionally empty.
}

const HEALTH_PATH = "/v1/health";

function plain(status: number, body: string): Response {
  return new Response(body, {
    status,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

/** Exported for unit tests (no network). */
export function handleRequest(request: Request): Response {
  let url: URL;
  try {
    url = new URL(request.url);
  } catch {
    return plain(400, "Bad Request");
  }

  if (url.username || url.password) {
    return plain(400, "Bad Request");
  }

  if (url.pathname !== HEALTH_PATH) {
    return plain(404, "Not Found");
  }

  if (url.search || url.hash) {
    return plain(400, "Bad Request");
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
    _env: Env,
    _ctx: ExecutionContext,
  ): Promise<Response> {
    return handleRequest(request);
  },
};
