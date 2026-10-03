# Mercury Gateway wire protocol v1

Status: contract + fixtures. The Worker still serves only `GET /v1/health`. `GatewayAIProvider` is M3-T3 and is not in this cut.

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

A stream that ends without a terminal `done` or `error` is incomplete and must be rejected. No token is logged.

## `GET /v1/health`

`{ "ok": true, "service": "mercury-gateway" }`. No query. No fragment.

## `GET /v1/config`

`{ "protocol": "v1", "stream": ["meta", "delta", "done", "error"] }`. Auth required. Not implemented on the Worker in this cut.

## Fixtures

Canonical copies live in `gateway/fixtures/`. SPM replays the copies under `Tests/Fixtures/gateway/`. They must stay byte-identical. Tests load them via `#filePath` (not `Bundle.module`) so the same path works in SPM and the Xcode `QuicksilverTests` target.
