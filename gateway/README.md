# Mercury Gateway

Cloudflare Workers Free reverse proxy for Quicksilver cloud AI. The app binds a
gateway URL + device token only; provider keys live here (never in the iOS app).

This directory is the **M3-T15 scaffold**: `GET /v1/health` and CI unit tests.
Auth, budgets, streaming, and provider adapters land in M3-T16–T20.

## Route policy (fail closed)

- Only `GET /v1/health` is allowed.
- Query string, fragment, and userinfo return 400. A device token must not ride in the URL.
- Other methods on the health path return 405.
- Every other path returns 404 and the body does not echo the path.
- Workers Logs stay metadata-only. Do not log request or response bodies.

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
| `test/health.test.ts` | Vitest coverage (no network) |
| `wrangler.toml` | Free-tier Worker config + metadata-only observability |
| `package.json` | `npm test` → Vitest |

## CI

The Quicksilver **Structure & Contracts** job runs `npm ci && npm test` in this
directory so the four CI job names stay unchanged.
