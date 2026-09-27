# Quicksilver Hardening Report & Roadmap

**Last updated:** 2026-09-27 (M1-T12 docs sync: Codex bind path, aspects not personas, CI Xcode 26.3, iPhone 16e target)

## Device / OS policy

| Layer | Value | Reason |
|-------|-------|--------|
| Primary validation device | **iPhone 16e** / **iOS 27** | Owner device (updated 2026-09-19) |
| `IPHONEOS_DEPLOYMENT_TARGET` | **18.0** | Build floor; CI uses Xcode 26.3 (iOS 26 SDK) via `latest-stable` |
| `AppConfiguration.minimumOSVersion` | 18.0 | Matches build floor |
| `AppConfiguration.primaryDeviceOSVersion` | 27.0 | Honest about where we test |

Raising the minimum to 27.0 before CI has an iOS 27 SDK would break every Archive job and stop SideStore IPA production. Keep the floor at 18 until the runner SDK catches up; binaries built that way install and run correctly on iOS 27.

## Current ship

| Field | Value |
|-------|-------|
| Version | **0.2.0 (build 7)** |
| Branch | `main` |
| Sentry | Fully integrated — official `getsentry/sentry-cocoa` 9.25.0 via the **`Sentry`** product, DSN + refined privacy-conscious options, automatic dSYM upload on Archive when `SENTRY_AUTH_TOKEN` is set |
| Path | Actions → Archive IPA → Quicksilver-unsigned-IPA |

## Completed Hardening + Recent Work

### P0 — Correctness & Safety
- BatteryMonitor / NetworkMonitor / StorageMonitor / DeviceMetricsMonitor: main-queue delivery, token-based observers, explicit lifecycle
- GrokAIProvider: Task cancellation, 45 s timeout, no secret leakage in errors
- **LoggerService + QuicksilverLogger**: default privacy `.private`; improved `redact` covers token/secret/Bearer; explicit `isPrivate` opt-out only when intentional
- **PrivacyInfo.xcprivacy** present and embedded
- MercuryBrain: structured aspect switch (`switchAspect`) with error logging

### P1 — Architecture & Maintainability
- Persona prompts externalized to `Resources/Personas/*.txt`
- PromptManager loads external prompts with embedded fallback
- MemoryManager: `clearAll()` + `exportJSON()`
- InsightEngine: personaID is an optional traceability tag only; generation is persona-agnostic
- AppConfiguration documents both build floor (18) and primary device (27); version/build aligned to shipped 0.2.0 (7)

### P2 — Experience
- **PersonaTheme**: accent colors, density, card radius, bubble style per aspect
- **InsightPresenter**: distinct tone + action labels
- **ForgeView** + **EternalView** present on main as functional realms
- Sanctum as primary place with RealmGateway transitions

### CI / SideStore / Observability
- CI upgraded: `maxim-lobanov/setup-xcode`, strict SwiftLint job, improved SPM + DerivedData caching
- Archive IPA: unsigned SideStore path + optional signed path + **automatic Sentry dSYM upload**
- Structure job enforces modular layout + Core contracts + PrivacyInfo
- Version / build banner + persona prompt verification in Archive
- Sentry dependency corrected to official product

### Architecture invariants preserved
- Sense → Think → Express
- Core owns contracts only
- Nexus remains persona-agnostic
- UI stays presentation-only
- DependencyContainer is the composition root
- MercuryBrain remains the central intelligence coordinator

---

## Development Roadmap Status

### Milestone 1 — Foundation Stability → Done
### Milestone 2 — Device Intelligence → Done
### Milestone 3 — Memory System → Done
### Milestone 4 — AI Integration → Largely done
### Milestone 5 — Polished UI / Personality → Slice A landed + Forge/Eternal realms on main
### Milestone 6 — SideStore production hardening → Done (plus Sentry)
### Living Realms v1 → In progress (GitHub #57)

Remaining focus:
- M2 test and CI foundation (AppTests, iPhone 16e simulator preference, full-repo strict lint)
- M3 Mercury Gateway and free cloud intelligence; M3.5 Apple Intelligence and App Intents
- Accessibility / Dynamic Type / Reduce Motion pass
- First formal GitHub Release once quality gate is satisfied

---

## Branch Hygiene Recommendation

Keep:
- `main`
- active living-realms / hygiene branches only while open

Safe to close / delete after confirming no unique unmerged value:
- Older `forge/p1-*` branches
- `day-one-foundation`, `core-intelligence-layer*`, `stabilization-pass`, `audit-fixes-and-sidestore-deployment`
- Stale Dependabot branches once their PRs are merged or closed

The existing `prune-branches.yml` will automatically delete *merged* remote branches.

---

## Device Validation Checklist (iPhone 16e / iOS 27)

1. Trigger **Actions → Archive IPA → Run workflow** (Release)
2. Download **Quicksilver-unsigned-IPA** artifact
3. Install via SideStore (LocalDevVPN connected)
4. Launch → Sanctum / Home shows Quicksilver presence + Nexus health
5. Enter Forge → awaken, capture notes, ask
6. Enter Eternal → observe signals / memory constellation
7. Confirm aspect overrides (Quicksilver / Forge / Eternal via Diagnostics) — accent, density, insight tone change; autonomous default when unset; no persona switcher
8. Codex → bind keys (free Gemini; optional Grok) — binding the first key enables intelligence
9. Memory → policy label, add/delete/clear/export
10. Background 5–10 min → no excessive drain
11. Force-quit + relaunch → state intact
12. Confirm PrivacyInfo.xcprivacy present inside the installed app
13. Confirm no sensitive data (keys, tokens, memory contents) appears in Console / sysdiagnose under default logging

No private APIs. Keychain for secrets only. Sentry active when configured. Logger defaults to private.
