# Portfolio 10-phase roadmap — 2026-09-27 16:01 EDT

1. Ready-or-refuse on Resonance main — DONE. Live 503 until SERVICE_ROLE.
2. Owner sets `SUPABASE_SERVICE_ROLE_KEY` on resonancenexus only. Exit: `/api/ready` 200. Confirmed still missing at 16:01. Env list still has URL/anon/auth/project id/deploy stage/public project id only.
3. Durable `github.repository.read` evidence with deny proofs. Needs `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET` on the live host.
4. Quicksilver device HG CHR-55 on iPhone 16e from `7178fa78` or later. Simulator CI is not acceptance.
5. Quicksilver next code slice after HG: M2-T1 app-hosted tests or CHR-12 a11y. P-T1 through P-T6/P-T18 and M1-T5 through M1-T12 shipped. P-T4 stays behind M3.5-T4.
6. Conduit freeze; repair #119/#120 off current main (`82013db1`) only. Do not merge red.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200 after #143. #144 grant-admin memoize is on main.
8. Resonance iOS I1 against a ready host. Blocked by phase 2.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive abandoned `cknowlesbadluck/Quicksilver` and stale `mcp`.
