# Portfolio 10-phase roadmap — 2026-09-28 18:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live `/api/ready` still 503.
2. Owner SERVICE_ROLE: key exists on resonancenexus production context (secret, production, updated 13:01 EDT). Live process still reports missing. Exit remains `/api/ready` 200 after a GitHub-backed production redeploy. Do not invent secrets. Do not upload an empty sandbox over the site.
3. Durable `github.repository.read` evidence with deny proofs. Needs `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET` on the live host. Still absent by name.
4. Quicksilver device HG CHR-55 on iPhone 16e from `652d1070` or later. Simulator CI is not acceptance.
5. M2-T1 app-hosted XCTest — DONE (#188 at `652d1070`). M2-T2 16e destination preference opened this hour. Next after that: M2-T3 injectable container. P-T4 stays behind M3.5-T4.
6. Conduit freeze; repair #119/#120 off current main (`4838170a` after #149) only. Do not merge red.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200. #144 grant-admin memoize on main. #149 status sanitization on main.
8. Resonance iOS I1 against a ready host. Blocked by phase 2 exit (`/api/ready` 200), not by the key name existing.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive stale `mcp`. No delete-ref tool on this connector.
