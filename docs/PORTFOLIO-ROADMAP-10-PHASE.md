# Portfolio 10-phase roadmap — 2026-09-27 13:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live 503 until SERVICE_ROLE.
2. Owner sets `SUPABASE_SERVICE_ROLE_KEY` on resonancenexus only. Exit: `/api/ready` 200. Confirmed still missing at 13:00. Env list is URL/anon/auth/project id/deploy stage/public project id only.
3. Durable GitHub adapter evidence. Needs live `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET`.
4. Quicksilver device HG CHR-55 on iPhone 16e from `a1593bf3` or later. Simulator CI is not acceptance.
5. Quicksilver next code slice after HG: M1-T11 fold MercuryVisualTokens, or M2-T1 app-hosted tests, or CHR-12 a11y. P-T1/P-T2/P-T3/P-T18/P-T5/P-T6/M1-T5 through M1-T10 shipped. P-T4 stays behind M3.5-T4.
6. Conduit freeze; repair #119/#120 off current main (`f4e7ec9c`). Do not merge red. #119 verify remains failed on stale head.
7. Conduit #125 keyset pagination — DONE. HTTP `GET /diagnostics` — DONE live 200 after #143. #144 grant-admin memoize is on main.
8. Resonance iOS I1 against a ready host. Blocked by phase 2.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive abandoned `cknowlesbadluck/Quicksilver` and stale `mcp`.
