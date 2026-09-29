# Portfolio 10-phase roadmap — 2026-09-29 07:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live `/api/ready` still 503.
2. Owner SERVICE_ROLE: key exists on resonancenexus production context (secret, production only, updated 13:01 EDT 2026-09-28). Live process still reports missing because published production is `6ab8ea11` / `5aeffb41`. `main--resonancenexus` also 503 — branch context does not receive the production secret. Exit remains `/api/ready` 200 after a GitHub-backed **production** republish of current main. Do not invent secrets. Do not upload an empty sandbox over the site.
3. Durable `github.repository.read` evidence with deny proofs. Needs `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET` on the live host. Still absent by name. #131 bounds response reads but remains mergeable_state blocked. #132 custom catalog is new and not merged.
4. Quicksilver device HG CHR-55 on iPhone 16e from `660c2b25` or later. Simulator CI is not acceptance.
5. M2-T1 app-hosted XCTest — DONE (#188). M2-T2 16e destination — DONE (#189). Autonomous aspect + Sanctum layout — DONE (#190 at `660c2b25`). M2-T3 + COS-T1 opened as #191. Structure, SwiftLint, SPM Unit Tests green. iOS Simulator Build failed. Do not merge #191 until that required job is green. Repair must not smash the shipped PersonaTheme token contract.
6. Conduit freeze; repair #119/#120 off current main (`4838170a` after #149) only. Do not merge red. #152 stays open while unstable. #153 Bolt publishEvent Set iteration is not merged.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200. #144 grant-admin memoize on main. #149 status sanitization on main.
8. Resonance iOS I1 against a ready host. Blocked by phase 2 exit (`/api/ready` 200), not by the key name existing.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive stale `mcp`. No delete-ref tool on this connector.
