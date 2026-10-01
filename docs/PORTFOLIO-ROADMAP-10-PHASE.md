# Portfolio 10-phase roadmap — 2026-10-01 03:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live `/api/ready` still 503 on production deploy `6ab8ea11`. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. #139 locked that shape on main `d27ffb42`. Do not invent the secret. Do not Netlify-deploy from this sandbox.
2. Owner sets / exposes `SUPABASE_SERVICE_ROLE_KEY` on resonancenexus only, then GitHub-backed production redeploy. Exit: `/api/ready` 200. Still open. CHR-54.
3. Durable `github.repository.read` evidence with deny proofs. Code for bounded reads is on Resonance main after #131. Still needs live `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET`.
4. Quicksilver device HG CHR-55 on iPhone 16e from green main `22d37ebc` or later. Simulator CI is not acceptance.
5. Quicksilver code: #198 squashed. Next agent slice is M2-T6 (this branch): Memory load/clear/export, Forge awaken + captureNote, Eternal awaken + captureObservation. P-T4 stays behind M3.5-T4. #193 stays behind main, not merged.
6. Conduit freeze; repair #119/#120 off current main (`b582429b`) only. Do not merge red. Do not merge #155 until Render TLS env is set.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200. #152 path guard and #156 rate-limiter eviction are on main. `activity_prune` this pass removed 0 rows.
8. Resonance iOS I1 against a ready host. Blocked by phase 2. #134 stays open, not merged ahead of ready.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `counsel/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive abandoned `cknowlesbadluck/Quicksilver`. No delete-ref tool on this connector.

## Innovative implementations this pass

A. Squashed #198. UI smoke is its own job and green. Main is no longer red.
B. Squashed #139. Live 503 shape is a contract, not a comment.
C. M2-T6: blank notes do not write; Forge/Eternal captures stay entity-wide (`personaScope == nil`); awaken is an aspect projection, not a second persona.
