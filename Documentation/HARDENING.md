# Quicksilver Hardening Report & Roadmap

**Last updated:** 2026-08-10 (Coordinate cycle — CI + Sentry + version regime)

## Device / OS policy

| Layer | Value | Reason |
|-------|-------|--------|
| Primary validation device | iPhone 14 / **iOS 27** | User device |
| `IPHONEOS_DEPLOYMENT_TARGET` | **18.0** | CI runners (Xcode 16) only ship iOS 18 SDK |
| `AppConfiguration.minimumOSVersion` | 18.0 | Matches build floor |
| `AppConfiguration.primaryDeviceOSVersion` | 27.0 | Honest about where we test |

Raising the minimum to 27.0 before CI has an iOS 27 SDK would break every Archive job and stop SideStore IPA production. Keep the floor at 18 until the runner SDK catches up; binaries built that way install and run correctly on iOS 27.

## Current ship

| Field | Value |
|-------|-------|
| Version | **0.2.0 (build 7)** |
| Branch | `main` |
| Sentry | Fully integrated (DSN + refined options + automatic dSYM upload on Archive when `SENTRY_AUTH_TOKEN` is set) |
| Path | Actions → Archive IPA → Quicksilver-unsigned-IPA |

## Completed Hardening + Recent Work

### P0 — Correctness & Safety
- BatteryMonitor / NetworkMonitor / StorageMonitor / DeviceMetricsMonitor: main-queue delivery, token-based observers, explicit lifecycle
- GrokAIProvider: Task cancellation, 45 s timeout, no secret leakage in errors
- LoggerService: redaction helper for API keys / long tokens
- **PrivacyInfo.xcprivacy** present and embedded
- DependencyContainer: structured persona switch with error logging

### P1 — Architecture & Maintainability
- Persona prompts externalized to `Resources/Personas/*.txt`
- PromptManager loads external prompts with embedded fallback
- MemoryManager: `clearAll()` + `exportJSON()`
- InsightEngine: personaID is an optional traceability tag only; generation is persona-agnostic
- AppConfiguration documents both build floor (18) and primary device (27)

### P2 — Experience
- **PersonaTheme**: accent colors, density, card radius, bubble style per persona
- **InsightPresenter**: distinct tone + action labels
- **ForgeView** + **EternalView** present on main as functional realms
- Sanctum as primary place with RealmGateway transitions

### CI / SideStore / Observability (2026-08-10)
- CI upgraded: `maxim-lobanov/setup-xcode`, strict SwiftLint job, improved SPM + DerivedData caching
- Archive IPA: unsigned SideStore path + optional signed path + **automatic Sentry dSYM upload**
- Structure job enforces modular layout + Core contracts + PrivacyInfo
- Version / build banner + persona prompt verification in Archive

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
### Living Realms v1 → In progress (GitHub #57 + Linear CHR-10 / CHR-11 / CHR-12)

Remaining focus:
- Finish functional depth of Forge + Eternal (actions, visualization, quality)
- Accessibility / Dynamic Type / Reduce Motion pass (CHR-12)
- Branch hygiene (many historical forge/sprint branches still present)
- First formal GitHub Release once quality gate is satisfied

---

## Branch Hygiene Recommendation

Keep:
- `main`
- `sprint/living-realms-v1` (active product work)

Safe to close / delete after confirming no unique unmerged value:
- Older `forge/p1-*` branches
- `day-one-foundation`, `core-intelligence-layer*`, `stabilization-pass`, `audit-fixes-and-sidestore-deployment`
- Stale Dependabot branches once their PRs are merged or closed
- `feature/release-workflow` (reconcile any useful bits then retire)

The existing `prune-branches.yml` will automatically delete *merged* remote branches.

---

## Device Validation Checklist (iPhone 14 / iOS 27)

1. Trigger **Actions → Archive IPA → Run workflow** (Release)
2. Download **Quicksilver-unsigned-IPA** artifact
3. Install via SideStore (LocalDevVPN connected)
4. Launch → Sanctum / Home shows persona + Nexus health
5. Enter Forge → awaken, capture notes, ask
6. Enter Eternal → observe signals / memory constellation
7. Switch personas — confirm accent, density, insight tone change
8. Settings → paste xAI key → enable AI Service
9. Memory → policy label, add/delete/clear/export
10. Background 5–10 min → no excessive drain
11. Force-quit + relaunch → state intact
12. Confirm PrivacyInfo.xcprivacy present inside the installed app

No private APIs. Keychain for secrets only. Sentry active when configured.
