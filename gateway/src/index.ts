/**
 * Mercury Gateway Worker (scaffold).
 * M3-T15: health endpoint only. Auth, streaming, and providers land in later M3 tasks.
 *
 * Privacy: never log request or response bodies — Workers Logs stay metadata-only.
 */

export interface Env {
  // Secrets and bindings arrive in M3-T16+ / HG3. Scaffold intentionally empty.
}

/** Exported for unit tests (no network). */
export function handleRequest(request: Request): Response {
  const url = new URL(request.url);

  if (request.method === "GET" && url.pathname === "/v1/health") {
    return Response.json(
      { ok: true, service: "mercury-gateway" },
      {
        status: 200,
        headers: { "cache-control": "no-store" },
      },
    );
  }

  return new Response("Not Found", {
    status: 404,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
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
