# Quicksilver Hardening Report & Roadmap

**Last updated:** 2026-09-27 (M1-T12 docs sync: Codex bind path, aspects not personas, CI Xcode 26.3, iPhone 16e target)

## Device / OS policy

| Layer | Value | Reason |
|-------|-------|--------|
| Primary validation device | **iPhone 16e** / **iOS 27** | Owner device (updated 2026-09-19) |
| `IPHONEOS_DEPLOYMENT_TARGET` | **18.0** | Build floor; CI selects `latest-stable` (currently Xcode 26.3 / iOS 26 SDK) |
| `AppConfiguration.minimumOSVersion` | 18.0 | Matches build floor |
| `AppConfiguration.primaryDeviceOSVersion` | 27.0 | Honest about where we test |

Raising the minimum to 27.0 before CI has an iOS 27 SDK would break every Archive job and stop SideStore IPA production. Keep the floor at 18 until the runner SDK catches up; binaries built that way install and run correctly on iOS 27.

## Current ship

| Field | Value |
|-------|-------|
| Version | **0.2.0 (build 7)** |
| Branch | `main` |
| Crash reporting | None. Sentry (SDK, DSN, dSYM upload) was removed on 2026-09-29 by owner decision; no crash, performance or diagnostic data leaves the device |
| Path | Actions → Archive IPA → Quicksilver-unsigned-IPA |

## Completed Hardening + Recent Work

### P0 — Correctness & Safety
- BatteryMonitor / NetworkMonitor / StorageMonitor / DeviceMetricsMonitor: main-queue delivery, token-based observers, explicit lifecycle
- GrokAIProvider: Task cancellation, 45 s timeout, no secret leakage in errors
- **LoggerService** (the only logger; the unused `QuicksilverLogger` was removed 2026-10-15): default privacy `.private`; improved `redact` covers token/secret/Bearer; explicit `isPrivate` opt-out only when intentional
- **PrivacyInfo.xcprivacy** present and embedded
- MercuryBrain: structured aspect switch (`switchAspect`) with error logging

### Surface guards (source-scanning tests, comments and strings ignored)
Each fails CI on a new offender and on a stale allowlist entry.
- Only MercuryBrain sets VisualState: `VisualStateOwnershipGuardTests` (#397, main `1dfb92a`, CI run 40259671964 green)
- Network I/O only in reviewed clients: `NetworkSurfaceGuardTests` (#400, main `8042e05`, CI run 40262020890 green)
- UserDefaults only in reviewed settings stores, no iCloud key-value sync: `DefaultsSurfaceGuardTests` (#401, main `a344a8d`, CI run 40266985184 green)
- Open in #409 (not on main): FoundationModels only in the on-device adapter; direct file writes only in reviewed stores; `nonisolated(unsafe)` ratchet; docs version-stamp check; no clipboard, location, contacts, calendar, photos, camera, microphone or health access without privacy review (`SensitiveCapabilitySurfaceGuardTests`)

### Deep audit 2026-10-26 (9 AM ET, main `a344a8d`)
- Privacy manifest: disk space is read (`Nexus/StorageMonitor.swift:48-50`) and shown to the user (`Nexus/InsightEngine.swift:103-110`), but only `E174.1` was declared. #411 adds `85F4.1` plus `PrivacyManifestReasonTests`. FileTimestamp and SystemBootTime are declared but unused (harmless). Disk space never reaches the cloud prompt (`CloudContextPolicy.allowedDeviceLines`).
- Unbounded store: `IntegrationEventStore` was append-only, rewrote its whole file on each append, and wrote without explicit Data Protection. #410 caps it at 1,000 events and sets `.completeFileProtectionUntilFirstUserAuthentication` on both integration stores. The Integration plane (`IntegrationRouter`) is not wired into the app yet; only tests construct it.
- SwiftData memory store (`Memory/SwiftDataMemoryStore.swift:15`) relies on the iOS default protection class. That is acceptable, but it isn't asserted by a test.
- `@unchecked Sendable`: 1 production site left (`Core/LoggerService.swift:12`, issue #252, fixed by open #284).

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
- Archive IPA: unsigned SideStore path + optional signed path + dSYMs artifact
- Structure job enforces modular layout + Core contracts + PrivacyInfo
- Version / build banner + persona prompt verification in Archive
- Sentry removed (2026-09-29)

### Architecture invariants preserved
- Sense → Think → Express
- Core owns contracts only
- Nexus remains persona-agnostic
- UI stays presentation-only
- DependencyContainer is the composition root
- MercuryBrain remains the central intelligence coordinator

---

## Development Roadmap Status

### Historical slices (pre-roadmap numbering) → Done
Foundation Stability · Device Intelligence · Memory System · AI Integration · Polished UI / Personality (Slice A + Forge/Eternal) · SideStore hardening.

### Production roadmap (`docs/ROADMAP.md`) — remaining focus
- **M2 — Test & CI foundation** (AppTests, iPhone 16e simulator preference, full-repo strict lint) — distinct from the completed historical "Device Intelligence" slice above
- **M3** Mercury Gateway and free cloud intelligence; **M3.5** Apple Intelligence and App Intents
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
7. Confirm Diagnostics displays the Brain's active aspect without selection controls; accent, density, and insight tone change with context
8. Codex → bind keys (free Gemini; optional Grok) — binding the first key enables intelligence
9. Memory → policy label, add/delete/clear/export
10. Background 5–10 min → no excessive drain
11. Force-quit + relaunch → state intact
12. Confirm PrivacyInfo.xcprivacy present inside the installed app
13. Confirm no sensitive data (keys, tokens, memory contents) appears in Console / sysdiagnose under default logging

No private APIs. Keychain for secrets only. No crash-reporting SDK. Logger defaults to private.
