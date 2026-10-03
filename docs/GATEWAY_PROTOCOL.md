# Mercury Gateway wire protocol v1

Status: contract + fixtures. The Worker still serves only `GET /v1/health`. `GatewayAIProvider` is M3-T3 and is not in this cut.

## Auth

`Authorization: Bearer <device token>`. Never a query string, fragment, or userinfo. `GatewayWireDecoder.rejectTokenInURL` is the client-side reject.

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

A successful stream is `meta`, zero or more `delta`, then `done`. An error stream is a single `error` event. No token is logged.

## `GET /v1/health`

`{ "ok": true, "service": "mercury-gateway" }`. No query. No fragment.

## `GET /v1/config`

`{ "protocol": "v1", "stream": ["meta", "delta", "done", "error"] }`. Auth required. Not implemented on the Worker in this cut.

## Fixtures

Canonical copies live in `gateway/fixtures/`. SPM replays the copies under `Tests/Fixtures/gateway/`. They must stay byte-identical.
