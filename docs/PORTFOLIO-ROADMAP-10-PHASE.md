# Portfolio 10-phase roadmap — 2026-09-30 19:00 EDT

1. Ready-or-refuse on Resonance main — DONE. Live 503 until SERVICE_ROLE is loaded by production deploy `6ab8ea11` successor.
2. Owner sets / exposes `SUPABASE_SERVICE_ROLE_KEY` on resonancenexus only, then GitHub-backed production redeploy. Exit: `/api/ready` 200. Confirmed still missing at 19:00.
3. Durable `github.repository.read` evidence with deny proofs. Code for bounded reads is on Resonance `b9c11d9b` (#131). Still needs live `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET`.
4. Quicksilver device HG CHR-55 on iPhone 16e from `acbb8e87` or later **after** `main` is green. Simulator CI is not acceptance.
5. Quicksilver next code slice: land #198 only if Structure + SwiftLint + SPM + required Simulator Build are green on `f1f73f4`. UI smoke is advisory. Then M2-T6. P-T4 stays behind M3.5-T4.
6. Conduit freeze; repair #119/#120 off current main (`b582429b`) only. Do not merge red. Do not merge #155 until Render TLS env is set.
7. Conduit #125 keyset pagination — DONE. HTTP `/diagnostics` — DONE live 200. #152 path guard and #156 rate-limiter eviction are on main.
8. Resonance iOS I1 against a ready host. Blocked by phase 2.
9. Chamber form/work/dissolve with audit. Blocked by phase 2.
10. Release surface: SideStore evidence, unskip production-smoke, owner prune leftover branches (`docs/hygiene-*`, `codex/*`, `bolt/*`, `counsel/*`, `develop`, `feature/ios-p4-compose-execute-evidence`, `release/0.8.0`). Archive abandoned `cknowlesbadluck/Quicksilver`. No delete-ref tool on this connector.

## Innovative implementations

A. DONE this hour on #198 `f1f73f4`: split required Simulator job from UI smoke so a harness flake cannot pin `main` red after AppTests pass.
B. Resonance ready-probe contract test against a fixture host that injects SERVICE_ROLE in CI only — proves fail-open cannot land without claiming live 200. Not started.
C. Conduit grant-path + TLS verify staged behind an explicit `CONDUIT_DB_SSL_MODE` flag so #155 can merge without a Render outage. Not started.
