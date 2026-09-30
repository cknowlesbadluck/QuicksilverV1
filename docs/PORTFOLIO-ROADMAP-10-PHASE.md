# Portfolio 10-phase roadmap — 2026-09-30 05:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live `/api/ready` still 503.
2. Owner SERVICE_ROLE: key exists on resonancenexus production context (secret, production only). Live process still reports missing because published production is `6ab8ea11`. Exit remains `/api/ready` 200 after a GitHub-backed **production** republish of current main. Do not invent secrets. Do not upload an empty sandbox over the site.
3. Durable `github.repository.read` evidence with deny proofs. Needs `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET` on the live host. Still absent by name. #131/#132/#133 stay unmerged (GHAS red or blocked). GHAS is not the ready gate.
4. Quicksilver device HG CHR-55 on iPhone 16e from `4f9660ff` or later. Simulator CI is not acceptance.
5. M2-T1 — DONE (#188). M2-T2 — DONE (#189). Autonomous aspect + Sanctum layout — DONE (#190). Constitution — DONE (#194 at `4f9660ff`). Next slice is **#195 tests green**, not more constitution docs. #195 already carries injectable `DependencyContainer` (M2-T3 seam). Do not merge while SPM Unit Tests or app-hosted tests are red. Keep #193/#191 closed until Simulator Build is green or superseded by a green #195.
6. Conduit freeze; repair #119/#120 off current main (`2fc021cf` after #154) only. Do not merge red. #152/#153 stay open. #155 waits on Render TLS env. #156 verify+postgres green; Workers Builds is not required.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200. #144 grant-admin memoize on main. #149 status sanitization on main. #154 diagnostics rate-limit + task_get scope on main.
8. Resonance iOS I1 against a ready host. Blocked by phase 2 exit (`/api/ready` 200). #134 iOS app target is not a substitute.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `counsel/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive stale `mcp` and close leftover PRs on `cknowlesbadluck/Quicksilver` (not V1). No delete-ref tool on this connector.

## Innovation (agent-owned vs owner-blocked)

Owner-blocked until a live constraint moves:
- CHR-54 GitHub-backed production republish so `/api/ready` 200.
- CHR-55 device IPA from `4f9660ff+`.
- Ready-identity stamp on `/api/ready` (git SHA + deploy id, no secrets) after the republish, so hygiene stops confusing dashboard keys with the live process.

Agent-owned this cycle, not merged:
- Isolate #195 failures: ProviderHTTPTests / SwiftData tests (SPM) and AppTests injection seam (app-hosted). Fix tests or the injection API, not PersonaTheme.
- Do not open another hygiene file set. Update these three files only.
- Hygiene freeze after this stamp unless CHR-54, CHR-55, or a required CI color changes.
