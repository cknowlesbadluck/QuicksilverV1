# Quicksilver — Audit Roadmap (2026-10-13)

Grounded in the 2026-10-13 audit. Swift code is in good shape (0 `try!`, 0 `as!`,
0 `fatalError`, 0 TODO/FIXME in prod; no SPM dependencies; Dependabot/secret-scanning
alerts: 0). Risk sits in CI/automation and repo hygiene. Merges stay with Quicksilver Dev.

| # | Phase | Goal | Key deliverables | Exit criteria | Risk |
|---|-------|------|------------------|---------------|------|
| 1 | CI & automation safety | Workflows least-privilege, bounded, non-destructive | ci.yml read-only perms + timeouts (#246); safe prune (#246); devcontainer fix (#247); remove one-shot `m1-t12-codex-fix.yml` (contents:write, targets dead branch) | All workflows have `permissions`, `timeout-minutes`; Codespaces prebuild green or disabled; no write-token one-shots | Low |
| 2 | Supply-chain pinning | Reproducible, tamper-resistant actions | SHA-pin all actions (Dependabot keeps them fresh); land/close Dependabot #209; add `dependabot.yml` npm for `gateway/` if missing | 0 tag-pinned third-party actions; Dependabot PRs < 7 days old | Low |
| 3 | Branch/PR hygiene | Stop doc-churn branch sprawl | Close/delete 9 PR-less `docs/roadmap-refresh-*`/`hygiene/*`/`audit*` branches; resolve #242/#244/#245; one living roadmap | ≤ 5 remote branches besides main; no PR > 7 days idle | Low |
| 4 | Docs consolidation | Single source of truth | Merge `docs/` + `Documentation/` portfolio/roadmap files; ARCHITECTURE reflects aspect model; docs-hygiene check covers both dirs | One ROADMAP, one ARCHITECTURE; docs-hygiene green | Low |
| 5 | Concurrency hardening | Retire `@unchecked Sendable` (13 sites) | Convert monitors/RoutingConfigStore/LoggerService to actors or `Mutex` (Synchronization); tests under TSan | ≤ 3 justified `@unchecked` with comments; TSan job green | Med |
| 6 | Test depth | Cover the Brain/Nexus seams | Coverage report from `swift test --enable-code-coverage` uploaded; tests for Nexus monitors, Intents, VisualState propagation | Coverage visible in CI; core modules ≥ 70% | Med |
| 7 | On-device model seam (M3.5-T1) | Brain can route to on-device model | Protocol-conforming provider behind DependencyContainer; eval harness parity | Fake + on-device paths pass eval smoke | Med |
| 8 | Gateway production readiness | Gateway safe to rely on | Rate-limit/budget alerts, `/v1/config` contract tests, secret rotation runbook | Gateway tests green; runbook in Documentation | Med |
| 9 | SideStore ship loop | Reliable IPA path | Archive workflow reproducible; release checklist; privacy manifest re-verified per release | Two consecutive clean IPAs installed on device (HG1) | Med (owner/device-gated) |
| 10 | Depth: Forge/Eternal instruments | Ship aspect depth on solid loop | VisualState complete; instruments via MercuryBrain/NexusCoordinator only | UI smoke + a11y green; no magic numbers (lint rule) | High (scope) |
