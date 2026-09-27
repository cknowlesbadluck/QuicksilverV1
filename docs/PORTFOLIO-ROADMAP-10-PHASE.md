# Portfolio 10-phase roadmap — 2026-09-27 06:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live 503 until SERVICE_ROLE.
2. Owner sets `SUPABASE_SERVICE_ROLE_KEY` on resonancenexus only. Exit: `/api/ready` 200. Confirmed still missing at 06:00.
3. Durable GitHub adapter evidence. Needs live tokens.
4. Quicksilver device HG CHR-55 on iPhone 16e from `d96c0804` or later. Simulator CI is not acceptance.
5. Quicksilver next code slice after HG: M2-T1 app-hosted tests or CHR-12 a11y. P-T1/P-T2/P-T3/P-T18/P-T5/P-T6/M1-T5/M1-T6/M1-T7 shipped. P-T4 stays behind M3.5-T4.
6. Conduit freeze; repair #119/#120 off current main. Do not merge red.
7. Conduit #125 keyset pagination — DONE. HTTP `GET /diagnostics` is on app-factory only. Production entrypoint fix is #143. Merge only if verify + postgres-coordination are green. Live proof is 200 JSON on `/diagnostics` after Render deploy.
8. Resonance iOS I1 against a ready host. Blocked by phase 2.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `release/0.8.0`). Archive abandoned `cknowlesbadluck/Quicksilver` and stale `mcp`.
