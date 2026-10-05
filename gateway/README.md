# Mercury Gateway

Cloudflare Workers Free reverse proxy for Quicksilver cloud AI. The app binds a
gateway URL + device token only; provider keys live here (never in the iOS app).

Landed so far: `GET /v1/health` (M3-T15); device-token auth, a per-token RPM
limit, and per-candidate daily budgets on `POST /v1/chat` (M3-T16); and the protocol
v1 stream layer plus a deterministic fake upstream (M3-T17); and the Gemini (main) and
OpenAI-compatible (Groq backup) adapters (M3-T18). The Workers AI adapter and the router
that wires adapters into `POST /v1/chat` land in M3-T19–T20; until then an admitted chat
request gets a typed `upstream_unavailable` event (or the fake stream in local `FAKE_MODE`).

## Route policy (fail closed)

- Only `GET /v1/health` and `POST /v1/chat` are routed.
- Query string, fragment, and userinfo return 400. A device token must not ride in the URL.
- Other methods on those paths return 405.
- Every other path returns 404 and the body does not echo the path.
- Workers Logs stay metadata-only. Do not log request or response bodies.

## Auth and limits (M3-T16)

`POST /v1/chat` checks, in order (each failure is one protocol v1 `error` event):

| Check | Failure |
|---|---|
| `Authorization: Bearer <token>` matches the `DEVICE_TOKEN` secret (SHA-256 digests compared in constant time; unset secret fails closed) | 401 + `unauthorized` |
| Per-token requests per minute (`rpmPerToken` in `config/routing.json`, sliding 60 s window) | 429 + `rate_limited` with `retryAfter` and `Retry-After` |
| At least one candidate still has `dailyBudget` left today (UTC) | 200 + `budget_exhausted`, so the app goes on-device |

`config/routing.json` lists candidates in the owner's order: Gemini Flash (main,
`trainsOnPrompts: true`) → Groq `openai/gpt-oss-120b` (backup) → Workers AI (last
resort). xAI is absent (optional, own credits only). Each `dailyBudget` stays below the
provider's free daily limit (`freeDailyRequests`), and under half of it when the
provider resets on another clock (Gemini resets at midnight Pacific). The free numbers
are public estimates; Christopher records the real ones from his consoles at HG3.

Counters are **best-effort and in-isolate**: each isolate counts on its own and resets
on eviction. There are no KV or storage writes per request and no paid bindings. The
Workers Rate Limiting binding is not used because its docs don't say it is part of
Workers Free.

## Stream layer and fake upstream (M3-T17)

`src/stream.ts` turns provider chunks (`delta` / `done` / `error`) into protocol v1
SSE and enforces the grammar in `docs/GATEWAY_PROTOCOL.md`:

- An error, throw, or empty upstream **before any output** comes back as
  `{ ok: false, error }` with nothing sent, so the router (M3-T20) can fail over.
- Otherwise the body is `meta` → deltas → `done`. A provider that throws or ends
  without a terminal chunk after output has begun is closed with an
  `upstream_unavailable` error (partial text kept).
- `retryAfter` and token counts are written as integers; `rate_limited` always has a
  `retryAfter`.
- Cancelling the response body aborts the upstream through its `AbortController`.

`src/providers/fake.ts` is a deterministic fake with scripted chunks, errors, throws
and delays. Each script in `FAKE_SCRIPTS` reproduces one `fixtures/*.sse` file byte for
byte (`test/stream.test.ts`).

**Local `FAKE_MODE` (development only).** Put `DEVICE_TOKEN=<any local value>` and
`FAKE_MODE=1` (or a script name such as `mid-stream-error`) in `gateway/.dev.vars`
(git-ignored; never commit it) and run `npm run dev`. Admitted chats
then stream from the fake. Auth, the RPM limit and budgets still apply. Never set
`FAKE_MODE` on the deployed Worker.

## Provider adapters (M3-T18)

Each adapter implements `Provider` from `src/stream.ts` and yields `delta` / `done` /
`error` chunks; the stream layer adds `meta` and enforces the grammar. They are not
wired into `POST /v1/chat` yet (the router does that in M3-T20, including
per-candidate context redaction before each attempt).

| Adapter | Upstream | Key |
|---|---|---|
| `src/providers/gemini.ts` (main) | `POST …/v1beta/models/{model}:streamGenerateContent?alt=sse` | `GEMINI_API_KEY` in the `x-goog-api-key` header |
| `src/providers/openaiCompatible.ts` (Groq backup; xAI / OpenRouter / Mistral later via another base URL) | `POST {baseUrl}/chat/completions`, `stream: true` | `GROQ_API_KEY` as `Authorization: Bearer` |

Shared behaviour (`src/providers/upstream.ts`, `src/providers/sse.ts`):

- **Prompt.** `system` messages become the system instruction; `context` blocks are
  rendered after it in one delimited `<untrusted_notes>` block that mirrors the app's
  M3-T12 format (one line per note, angle brackets neutralized, 180-character cap).
  Gemini gets `user` / `model` turns; OpenAI-compatible gets `system` / `user` /
  `assistant` messages. `maxTokens` becomes `maxOutputTokens` / `max_completion_tokens`.
- **Stream.** Text parts / `delta.content` become deltas. Gemini thought parts and
  OpenAI-style `reasoning` fields are skipped. Gemini `STOP` / `MAX_TOKENS` and
  OpenAI `[DONE]` (or a finish reason then EOF) end with `done` + usage. A blocked
  prompt, a safety stop or `content_filter` is `bad_request`. An in-stream error
  object or malformed JSON is `upstream_unavailable`. A stream that ends without a
  finish is reported as incomplete by the stream layer.
- **HTTP errors.** 429 → `rate_limited` with `Retry-After` (or Gemini's `RetryInfo`
  delay); 408 / 504 → `timeout`; 400 / 413 / 422 → `bad_request`; 401 / 403 / 404,
  other 4xx and 5xx → `upstream_unavailable`. An upstream 401 (or Gemini's 400
  `API_KEY_INVALID`) means the **gateway's** provider key is wrong, not the app's
  device token, so it is never sent to the app as `unauthorized`, and the router can
  fail over to the backup. A missing key yields `upstream_unavailable` without a
  network call.
- **Cancellation.** The abort signal goes to `fetch`, and the upstream body is
  cancelled when the stream stops early. An aborted attempt ends instead of reporting.
- **Privacy.** Bodies are never logged. Error bodies are read (at most 16 KiB) only for
  a retry delay or an invalid-key reason.

Tests (`test/gemini.test.ts`, `test/openaiCompatible.test.ts`, `test/sse.test.ts`,
`test/upstream.test.ts`) use an injected `fetch` and the streams in
`fixtures/upstream/`. Those fixtures are hand-written in each provider's documented
streaming format (no network and no keys are used here); HG3's eval run is the first
check against the live APIs.

## Constraints (owner decisions)

- **Free tier only.** No paid Cloudflare products. No payment method on the account.
- **No paid bindings** in `wrangler.toml` (no KV / R2 / D1 / Queues / AI yet).
- **Workers Logs = metadata only.** Do not `console.log` request or response bodies.
- **Agents never create accounts, deploy, or add secrets.** That is Christopher only (HG2 / HG3).

## Local checks

```bash
cd gateway
npm ci
npm test
npm run typecheck   # optional
```

## HUMAN GATE HG2 — deploy (Christopher only)

Agents must not run these steps. Christopher:

1. Create a **Cloudflare Workers Free** account with **no payment method** attached.
   Nothing paid: no Workers Paid, no R2, no KV namespaces for this scaffold.
2. On a machine with Node 20+:
   ```bash
   cd gateway
   npm ci
   npx wrangler login
   npx wrangler deploy
   ```
3. Note the `*.workers.dev` URL from the deploy output (e.g.
   `https://mercury-gateway.<subdomain>.workers.dev`). That URL is what you will
   bind later in the Codex (M3-T6 / HG4), together with a device token (HG3).
4. Confirm health:
   ```bash
   curl -sS "https://mercury-gateway.<subdomain>.workers.dev/v1/health"
   ```
   Expect `{"ok":true,"service":"mercury-gateway"}`.

Secrets (`DEVICE_TOKEN`, `GEMINI_API_KEY`, `GROQ_API_KEY`, …) are **HG3**, not this gate.

## Layout

| Path | Role |
|---|---|
| `src/index.ts` | Fetch handler and fail-closed route policy |
| `src/auth.ts` | Bearer `DEVICE_TOKEN` check, constant-time compare |
| `src/limits.ts` | Per-token RPM limiter, per-candidate daily budgets |
| `src/stream.ts` | Protocol v1 events, SSE encoding, stream grammar, provider interface |
| `src/providers/fake.ts` | Deterministic fake upstream + `FAKE_MODE` scripts |
| `config/routing.json` | Candidate order, `dailyBudget`, `rpmPerToken` (no secrets) |
| `test/*.test.ts` | Vitest coverage (no network) |
| `wrangler.toml` | Free-tier Worker config + metadata-only observability |
| `package.json` | `npm test` → Vitest |

## CI

The Quicksilver **Structure & Contracts** job runs `npm ci && npm test` in this
directory so the four CI job names stay unchanged.
