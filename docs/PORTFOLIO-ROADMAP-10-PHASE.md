# Portfolio 10-phase roadmap — 2026-09-29 21:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live `/api/ready` still 503.
2. Owner SERVICE_ROLE: key exists on resonancenexus production context (secret, production only). Live process still reports missing because published production is `6ab8ea11`. Exit remains `/api/ready` 200 after a GitHub-backed **production** republish of current main. Do not invent secrets. Do not upload an empty sandbox over the site.
3. Durable `github.repository.read` evidence with deny proofs. Needs `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET` on the live host. Still absent by name. #131/#132/#133 stay unmerged (GHAS red or blocked). GHAS is not the ready gate.
4. Quicksilver device HG CHR-55 on iPhone 16e from `4f9660ff` or later. Simulator CI is not acceptance.
5. M2-T1 — DONE (#188). M2-T2 — DONE (#189). Autonomous aspect + Sanctum layout — DONE (#190). Constitution — DONE (#194 at `4f9660ff`). Next slice: repair Simulator Build on #193 (fix for #191), then squash only if all required checks are green. Do not smash the shipped PersonaTheme token contract.
6. Conduit freeze; repair #119/#120 off current main (`2fc021cf` after #154) only. Do not merge red. #152/#153 stay open. #155 waits on Render TLS env.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200. #144 grant-admin memoize on main. #149 status sanitization on main. #154 diagnostics rate-limit + task_get scope on main.
8. Resonance iOS I1 against a ready host. Blocked by phase 2 exit (`/api/ready` 200). #134 iOS app target is red and is not a substitute.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `counsel/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive stale `mcp`. No delete-ref tool on this connector.
