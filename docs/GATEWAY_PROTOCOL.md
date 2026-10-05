# Mercury Gateway wire protocol v1

Status: contract + fixtures + client (`GatewayAIProvider`, M3-T3) + routing config decode (`AIRoutingConfig` / `RoutingConfigStore`, M3-T4). The Worker serves `GET /v1/health` and an auth- and limit-gated `POST /v1/chat` (M3-T16: `unauthorized`, `rate_limited`, `budget_exhausted`; `upstream_unavailable` until providers land). M3-T17 adds the Worker's stream layer (`gateway/src/stream.ts`) and a deterministic fake upstream whose scripts reproduce every fixture byte for byte. Full gateway router is M3-T20.

## Auth

`Authorization: Bearer <device token>`. Never a query string, fragment, or userinfo. The protocol defines **no query parameters**, so any `?…` on a gateway URL is a protocol violation. `GatewayWireDecoder.rejectTokenInURL` is the client-side reject.

## `POST /v1/chat`

JSON body:

- `taskTier` string
- `messages` array of `{ role, content }`
- `context` array of kind-tagged blocks: `history`, `summary`, `memory`, `device`, each with `text` and `privacy` (`device`, `ephemeral`, `cloud`)
- `privacy` on the request
- `maxTokens` positive integer

Response: `text/event-stream`.

| event | data |
| --- | --- |
| `meta` | `{ route, model, trainsOnPrompts }` |
| `delta` | `{ text }` |
| `done` | `{ usage: { promptTokens, completionTokens } }` or `{}` |
| `error` | `{ code, retryAfter? }` |

Error codes: `unauthorized`, `rate_limited` (requires `retryAfter`), `budget_exhausted`, `upstream_unavailable`, `bad_request`, `timeout`.

`retryAfter`, `promptTokens`, and `completionTokens` are integral integers only; fractional JSON numbers are rejected.

### Stream grammar

- **Success:** `meta` → zero or more `delta` → `done`.
- **Failure before output:** a single `error` event.
- **Failure after output has begun:** `meta` → zero or more `delta` → `error` (partial text is preserved for the caller; no further events).

A stream that ends without a terminal `done` or `error` is incomplete and must be rejected. Each SSE event must be terminated by a blank line; pending fields at EOF are discarded (WHATWG). No token is logged.

## `GET /v1/health`

`{ "ok": true, "service": "mercury-gateway" }`. No query. No fragment.

## `GET /v1/config`

Auth required (`Authorization: Bearer <device token>`). Returns the routing policy the client caches locally. **Never includes API keys or device tokens.**

```json
{
  "protocol": "v1",
  "stream": ["meta", "delta", "done", "error"],
  "tasks": {
    "answer": { "route": "cloud", "tier": "main" },
    "plan": { "route": "onDevice" },
    "tools": { "route": "onDevice" },
    "memory": { "route": "onDevice" },
    "summaries": { "route": "onDevice" }
  },
  "tiers": {
    "main": {
      "displayModel": "Gemini Flash",
      "trainsOnPrompts": true,
      "contextLevel": "minimal"
    },
    "backup": {
      "displayModel": "Groq gpt-oss-120b",
      "trainsOnPrompts": false,
      "contextLevel": "standard"
    },
    "lastResort": {
      "displayModel": "Workers AI",
      "trainsOnPrompts": false,
      "contextLevel": "standard"
    }
  },
  "timeouts": {
    "connect": 10,
    "firstEvent": 20,
    "idle": 15,
    "total": 90
  },
  "retry": {
    "maxAttempts": 1,
    "honorRetryAfter": true
  }
}
```

- `tasks.*.route`: `onDevice` or `cloud` (cloud requires `tier`: `main` | `backup` | `lastResort`).
- `tiers.*.contextLevel`: `standard` | `minimal`. Any tier with `trainsOnPrompts: true` **must** use `minimal`.
- `retry.maxAttempts`: `0` or `1` in this cut.
- Not fully implemented on the Worker yet (M3-T20). The client tolerates fetch failure and keeps the bundled / cached copy (`RoutingConfigStore`).

## Fixtures

Canonical copies live in `gateway/fixtures/`. SPM replays the copies under `Tests/Fixtures/gateway/`. They must stay byte-identical. Tests load them via `#filePath` (not `Bundle.module`) so the same path works in SPM and the Xcode `QuicksilverTests` target. The app also ships `Resources/ai-routing.default.json` (same routing semantics) for offline boot.
