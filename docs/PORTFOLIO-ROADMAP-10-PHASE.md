# Portfolio 10-phase roadmap — 2026-09-30 23:03 EDT

1. Ready-or-refuse on Resonance main — DONE. Live `/api/ready` still 503 on production deploy `6ab8ea11`. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. Auth mode is required and ok. Do not invent the secret. Do not Netlify-deploy from this sandbox.
2. Owner sets / exposes `SUPABASE_SERVICE_ROLE_KEY` on resonancenexus only, then GitHub-backed production redeploy. Exit: `/api/ready` 200. Still open. CHR-54.
3. Durable `github.repository.read` evidence with deny proofs. Code for bounded reads is on Resonance `b9c11d9b` (#131). Still needs live `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET`.
4. Quicksilver device HG CHR-55 on iPhone 16e from a green `main`. Simulator CI is not acceptance.
5. Quicksilver code: #198 `955585a` hardens the UI smoke terminate race (destinations passed; accessibility died in `launch()` terminating pid 31726). Do not squash until the new required checks and UI smoke are green. Then M2-T6. P-T4 stays behind M3.5-T4. #193 stays behind main, not merged.
6. Conduit freeze; repair #119/#120 off current main (`b582429b`) only. Do not merge red. Do not merge #155 until Render TLS env is set.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200. #152 path guard and #156 rate-limiter eviction are on main. `activity_prune` this pass removed 0 rows.
8. Resonance iOS I1 against a ready host. Blocked by phase 2. #134 stays open, not merged ahead of ready.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `counsel/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive abandoned `cknowlesbadluck/Quicksilver`. No delete-ref tool on this connector.

## Innovative implementations

A. Pushed on #198 `955585a`: UI smoke reuses the running app instead of `launch()` terminate. The product path already passed.
B. Opened `feat/ready-live-shape`: contract test locks the exact live 503 body (`missingRequired == [SUPABASE_SERVICE_ROLE_KEY]`, no secret echo). Fixture only. Not a production claim.
C. Conduit grant-path + TLS verify stays behind #155 until `CONDUIT_DB_SSL_MODE` can be set on Render. Not started. Do not merge #155.
