# QuicksilverV1 full audit (2026-10-24)

This is a blunt assessment of QuicksilverV1 only. Everything here was checked against `main` and the open PRs on 2026-10-24.

## Score: about 7.5 / 10

The architecture is solid. What holds the score down is the lack of device evidence and the process overhead, not the code.

## What is solid

- **Module boundaries are clear.** The app is split into App, Core, Services, Nexus, Memory, Intents, UI, Personas and Models. `DependencyContainer` does the wiring.
- **CI gates are real.** Quicksilver CI runs six jobs: Structure & Contracts, SwiftLint, SPM Unit Tests, SPM Thread Sanitizer, iOS Simulator Build and iOS UI Smoke. Main is green.
- **Source-scan guard tests enforce policy in code:**
  - logger privacy (`LoggerPrivacyGuardTests`)
  - Keychain accessibility (`KeychainPolicyGuardTests`)
  - public Apple APIs only (`PublicAPIGuardTests`)
  - the `@unchecked Sendable` ratchet
- **Memory resilience is tested.**
  - Load and save failures are surfaced without leaving phantom items (`MemoryFailureTests`).
  - Retention has a default budget of 1,000 conversation items and a 90-day age limit.
  - A load-time ceiling at that budget is in #388. On CI, loading 1,000 turns plus 500 notes took about 2–5 ms with the in-memory store and 0.09–0.22 s with SwiftData.
- **The version is single-sourced.** `MARKETING_VERSION` in `project.yml` (currently `0.2.0`) is the only source. At runtime `AppConfiguration` reads `CFBundleShortVersionString` and falls back to `AppConfiguration.fallbackVersion` only if that is missing or blank. A guard test (`LogPrivacyGuardTests`) checks that `project.yml` and `AppConfiguration` agree, so they can't drift apart silently. Re-verified with grep on 2026-10-24: there is no other hardcoded app version in Swift, plist, YAML or shell sources.

## Gaps

1. **No device IPA evidence (critical).** CHR-55 is `not_recorded`. Nothing in this repo proves the app installs and runs on a physical device. Simulator and SPM results do not stand in for that. This is the only gate blocking production, and it can't be closed from CI.
2. **Too many open PRs.** About 17 were open at the start of this pass. Most were stacked feature branches from 2026-10-17 that overlap #377 in `IntelligenceSurface` and `MemoryEntity`. This pass closed six of them: #319, #337, #340, #343, #345 and #348. Their branches are kept so the closes can be reversed. Eleven PRs remain open, and #373 and #374 conflict with main.
3. **Version hardcode: residual only.** This is no longer a real gap. The only copy outside `project.yml` is the guarded fallback constant. The remaining risk is that someone bumps `project.yml` without updating the fallback, and the guard test catches that.

## Risks

- **A known UI smoke flake.** The Workshop contrast check flakes on CI and needs a rerun now and then. The proper fix (`waitForSettledSanctum`) is in #373, which conflicts with main and is not merged.
- **Unmerged privacy work.** The NaturalLanguage privacy-gate work exists only on the closed #319's branch, as commit `4b40a2a`. The recovery steps are posted on #342.
- **Stale feature work.** The Spotlight notes work (#377) has one review comment still open, about tapping a result.
- **A path near release.** The unsigned IPA script (#375) is close to the archive and release path. It needs owner review, and nothing in this audit exercises it.

## Next actions

1. Record CHR-55 on a real device.
2. Merge the green, non-overlapping test PRs: #382, #387 and #388.
3. Rebase or close #373 and #374.
4. Resolve the last review comment on #377.
