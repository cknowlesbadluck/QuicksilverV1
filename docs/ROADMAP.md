> **Living document.** This is the production roadmap to Quicksilver 1.0. Update it in the same PR as the change that affects it: tick tasks, record owner decisions, and adjust milestones as evidence changes. Task IDs are stable; retired IDs are noted, not reused.

# Quicksilver (Mercury) — Roadmap to Production-Ready

Repo: `cknowlesbadluck/QuicksilverV1` @ `main` `43cdb47` (2026-09-25). Evidence comes from a fresh clone, the docs, `project.yml`/`Package.swift`/workflows, the last ~80 commits, PRs #76–#135, issue #57, CI logs, and a full-repo SwiftLint 0.65.1 `--strict` run. Each task is sized as one PR and is verified by **Quicksilver CI** (Structure & Contracts, SwiftLint, SPM Unit Tests, iOS Simulator Build). **HUMAN GATE** items are for the owner, not the build loop.

**Scope:** distribution is **SideStore only**, using the unsigned IPA from *Archive IPA* (README/AGENTS/SIDESTORE.md). Fastlane, Codemagic and the TestFlight step in `release.yml` stay **dormant, not deleted** (owner decision). Localization is out of scope for the single English-speaking owner (`developmentLanguage: en`; the repo has no string catalogs).

### Owner decisions (2026-09-25)
1. **Integration Fabric** (`Nexus/Integration/*`) stays **dormant for v1**, with no tasks. Revisit after 1.0.
2. **Ask** is redesigned before 1.0 into a non-chat "Invocation" surface (M5-T12, M5-T13).
3. **Forge/Eternal:** today's depth is enough for v1.
4. **Sentry** sends **errors and hangs only**. Tracing, profiling, metrics and failed-request capture are off (M4-T8).
5. **codemagic.yaml / fastlane / TestFlight** stay dormant and are documented as such (M6-T2).
6. **Intents** route through `MercuryBrain` via one small Core protocol, `IntelligenceSurface` (M1-T6).
7. **New requirement:** adopt Apple Intelligence frameworks and App Intents throughout (new **M3.5**).

---

## 1. Definition of production-ready (checklist)

- [ ] **CI:** all 4 CI jobs are green on `main`. SwiftLint `--strict` covers the **whole repo**, not only changed files. App-layer logic (MercuryBrain, view models) is unit-tested in CI. A UI smoke test plus an accessibility audit runs on the iPhone 16e simulator.
- [ ] **Install:** a fresh *Archive IPA* (Release) installs through SideStore on the owner's iPhone 16e / iOS 27. It launches to the Sanctum, and data and keys survive the 7-day refresh and a reinstall over the existing app.
- [ ] **AI:** Grok and Gemini keys can be bound, replaced and removed **from the reachable UI (Codex)**. Keys are stored in Keychain only and never appear in URLs, logs or Sentry. Grok is primary. Gemini takes over on primary failure but not on user cancel. Rate limits and server errors get a bounded retry. Offline skips the cloud providers instantly and routes to the on-device model, or fails with a clear message. No mock text ever reaches the user.
- [ ] **Brain:** conversation, Forge, Eternal and Intents all go through `MercuryBrain`. Multi-turn context is sent. Memory retrieval is relevant to the query. `.remember`/`.retrieve` intents act on memory. VisualState changes (thinking/speaking/warning) show in the UI.
- [ ] **Memory:** SwiftData store with a versioned schema, `@ModelActor` isolation and bounded growth (retention/pruning). Clear, export and load errors show in the UI. Memory is entity-wide, not scoped per persona.
- [ ] **Architecture:** no legacy persona/dashboard code (ContentView/HomeViewModel/SettingsView/PersonaDecisionPolicy/TaskKind shims, marker files, typealiases). Aspect vocabulary only. `PersonaTheme` + `MotionTokens` are the only token sources.
- [ ] **On-device intelligence:** a FoundationModels provider sits behind `AIProvider` and is gated by `#available(iOS 26.0, *)` and `SystemLanguageModel.default.availability`. It answers when you are offline or have no keys, and replaces the mock provider for users. When Apple Intelligence is unavailable, the app says why. Memory distillation and diagnosis use guided generation (`@Generable`). The on-device session can recall memory and device state through tools, and those tools read through the Brain.
- [ ] **App Intents throughout:** Memory, Aspect and Diagnostics are exposed as App Entities/Enums with queries. Memory intents adopt the `.journal` assistant schemas. Memories are indexed in Spotlight (`IndexedEntity`), with a Codex toggle. Ask/Status intents return Mercury-styled snippets, and an iOS 26 interactive snippet is included. All intents go through `IntelligenceSurface` → `MercuryBrain`, work from a cold start, and have fake-backed unit tests. "Open Diagnostics" opens Diagnostics. Shortcuts phrases are discoverable (at most 10).
- [ ] **System text features:** Writing Tools behavior is set deliberately on every text input.
- [ ] **Performance:** no polling loops in view models. Continuous animations pause when the view is hidden, inactive or under Reduce Motion, and slow down in Low Power Mode. A background soak shows no abnormal drain.
- [ ] **Accessibility:** every interactive element has a label. Dynamic Type works and Reduce Motion is honored. `performAccessibilityAudit()` passes for every destination.
- [ ] **Privacy/crash reporting:** the Privacy Manifest is accurate. Sentry sends **errors and hangs only** (no tracing/profiling/metrics/failed-request capture). Its config lives in one place, is scrubbed, is disabled under tests, has correct release/dist values and has an owner opt-out. Symbolicated crashes arrive in Sentry.
- [ ] **Ask is an Invocation surface**, not a generic chat UI (AGENTS.md "Mercury is a place").
- [ ] **Docs:** README, SIDESTORE.md and HARDENING.md match the app. A CHANGELOG exists. Version is 1.0.0.

## 2. Current state (honest summary)

The core is in good shape. `main` has been green since #132, and the four CI jobs pass on Xcode 26.3. The architecture is layered as specified: Core protocols, Nexus monitors with a signal pipeline, and a Brain-owned aspect and VisualState. #133 added the EventBus AsyncStream, #134 split the oversized files, and #135 (event-driven Forge/Eternal/Diagnostics) is open with CI green. Memory is SwiftData with a Keychain fallback. Keys are in Keychain with `AfterFirstUnlockThisDeviceOnly`. The code has no `fatalError`, `try!` or `print`.

It is **not production-ready**, and one issue is a ship-blocker:

- **API keys cannot be entered in the shipping UI.** The key fields exist only in `UI/SettingsView.swift`. That view is reachable only from the legacy `UI/ContentView.swift`, and nothing presents ContentView. `SanctumView` routes to `CodexView`, which shows key *status* but has no input.
- With no key, `AIService` falls back to `MockAIProvider`, and the user sees `"[Mock response]…"` text. `aiServiceEnabled` also defaults to `false`.

Other gaps:

- **Intents bypass the Brain.** They call `PersonaManager.switchTo` directly, which desyncs `MercuryBrain.activeAspect`.
- **Conversation is single-turn**, and memory retrieval ignores the query.
- **The Gemini key is sent as a URL query parameter.**
- **App-layer code has no CI tests.** Nothing in App/ or UI/ is exercised in CI, because CI only runs `swift test` and a simulator *build*.
- **A11y is thin, and performance has gaps.** Several 30 fps `TimelineView`s are never paused.
- **Latent lint debt.** 23 strict-lint violations sit in files that later PRs must touch.
- **Stale docs.** They claim an iOS 18 SDK, a persona switcher and an iPhone 14 target.
- **No recent device build.** The last *Archive IPA* run was 2026-09-18 21:57 ET, before the aspect architecture and Sanctum work.
- **No Apple Intelligence adoption yet.** There is no FoundationModels code, no Spotlight indexing, no assistant schemas and no snippets. CI already builds with Xcode 26.3 (iOS 26 SDK), so iOS 26 Apple Intelligence APIs compile today behind `#available`. iOS 27-only APIs do not, until runners ship Xcode 27.

## 3. Module audit (evidence)

| Module | What exists | Stubbed / legacy / risk | Tests |
|---|---|---|---|
| **Core** | `EventBus` (actor, callbacks + filtered AsyncStream), `KeychainStore`, `FeatureFlags` (schema v2 migration), `AppError`, `LoggerService` (`.private` default, `redact`), `IntentEngine`, `AspectPolicy`, `IntelligenceBroker`, models, 5 protocols | `AppConfiguration` hard-codes version `0.2.0`/`7`, duplicating `project.yml`. `KeychainStore.set` does delete-then-add, which is not atomic. FeatureFlags keys `personaSwitching`, `personaAutonomy`, `memoryPersistence`, `nexusDetailedMetrics` and `experimentalEventBus` are never read. `AppError` has no rate-limit/auth distinction. | Good (`CoreContractsTests` 24, `EventBusTests` 11, `LoggerServiceTests` 9). No Keychain tests. |
| **Memory** | `SwiftDataMemoryStore` (actor holding a `ModelContext`), `KeychainMemoryStore` fallback with legacy migration, `MemoryManager`, `MemoryQuery`, `MemoryScorer` | `ModelContext` is held in a plain actor instead of `@ModelActor`. No `VersionedSchema`. `pruneBelow` and `decayedImportance` are never used for retention, so growth is unbounded (every chat turn is stored). `clearAll` makes N single deletes. Load failures are only logged, and the UI shows an empty list. `UserDefaultsMemoryStore` typealias is a leftover. | InMemory store, manager, scorer, and query tests exist. **No `SwiftDataMemoryStore` tests.** |
| **Personas** | `PersonaManager` (projection-only), `PersonaConfiguration`, `PromptManager` (bundle + fallback), `PersonalityState`, `MemoryPolicy` | `PersonaDecisionPolicy`, `PersonaContext` (`TaskKind`/`QueryIntent`), the no-op `updateTaskContext` and ignored init params are legacy. `PersonalityState.swift` has 2 strict-lint violations. | `PersonaManagerTests` still tests the legacy decision policy. |
| **Services/AI** | `AIService` (Grok primary, Gemini fallback, flag gate, validator), `GrokAIProvider` (`grok-4.6`, 45 s timeout), `GeminiAIProvider` (`gemini-3.7-flash`) | **The Gemini key is sent as `?key=` in the URL** (`GeminiAIProvider.swift`). Fallback also fires on `CancellationError`. No retry/backoff. Model IDs are hard-coded. `MockAIProvider` is the silent default. `complete(userMessage:)` + `ContextAssembler` + `PromptBuilder` is a dead path (no production caller). `GrokAPIModels.swift` has 9 lint violations and `ContextAssembler` has 2. | Contract/flag/validator tests only. **No HTTP-level (URLProtocol) tests and no fallback test.** |
| **Nexus** | Network, battery, storage (120 s timer) and device monitors; `SignalProcessor` → `SignalPipeline` (2 s dedupe) → `NexusCoordinator`; `InsightEngine`; `AutomationBridge`; `Integration/*` (router, task/event stores, plane client) | Insights are not published on the EventBus (#135 needs a 60 s fallback for this reason). `overallHealthScore` averages network and power only; thermal and storage are ignored. **`Integration/*` (~800 LOC) is not referenced by App/UI/Intents. Owner decision: keep it dormant for v1 and revisit after 1.0; no tasks.** Monitors use `@unchecked Sendable` and rely on main-queue discipline. 6 lint violations. | Good (`NexusIntelligenceTests` 14, `IntegrationPlaneTests` 7). |
| **Intents** | 7 intents + `QuicksilverShortcuts`, `PersonaEntity`, `IntentDependencies` singleton | Intents bypass `MercuryBrain`: `ForcePersona`/`SwitchToForge` call `PersonaManager` directly, and `QueryNexus` calls `AIService` with its own keyword classifier. User-facing text still says "Persona". `OpenDiagnosticsIntent` is a no-op ("Future: deep-link"). `CaptureMemoryIntent` logs a content prefix and scopes memory to a persona. Intents throw `nexusNotReady` if the container is not configured (cold start). No `AppIntentsPackage` is declared, although the intents live in a framework. | **None.** |
| **App** | `QuicksilverApp` (Sentry init, scenePhase → Nexus), `DependencyContainer`, `MercuryBrain` (+`Composition`, `+Capabilities`) | Sentry DSN, sample rates (traces 0.2, profiling 0.1) and `releaseName "Quicksilver@0.2.0"` are hard-coded. No `beforeSend` scrubbing. `enableCaptureFailedRequests` is on while the Gemini key is in the URL. `Brain.invoke(_:)` has no callers. `retrieveRelevantMemory()` ignores the query. No history is sent to the AI. `CapabilitySurface.swift` is an empty marker. The container cannot be injected (stores are hard-coded). | **None:** App/ is not in the SPM package, and CI does not run `xcodebuild test`. |
| **UI** | Sanctum (spatial), Forge, Eternal (Observatory), Memory (Archive), Codex, Diagnostics, Ask sheet, visual system | **Codex has no key entry (ship-blocker).** Legacy `ContentView` + `HomeViewModel` (with a 2 s polling loop) are dead code. `SettingsView` is reachable only from dead code. Forge/Eternal/Diagnostics VMs still poll until #135 merges. `MercuryVisualTokens` (`MercuryVisualSystem.swift`) duplicates the PersonaTheme palette. Numeric literals in views: ForgeView 27, QuicksilverCoreView 18, EternalView 17, SpatialSanctum 15, ObservatoryPanels 15. `TimelineView(... paused: false)` runs even under Reduce Motion (`QuicksilverCoreView.swift:269`, `MercuryVisualSystem.swift:77`). Accessibility modifiers exist mainly in SpatialSanctum (11); Ask, Memory, Codex and Diagnostics have none. Ask is a bubble chat (AGENTS: "no generic chat UI"). VMs copy `brain.visualState` as a snapshot, and Sanctum filters out `aiRequestStarted`, so `.thinking` never shows there. `UI/VisualState.swift` is a leftover typealias. | **None** (the closed PRs #109–#128 tried and were not merged). |
| **Resources / Privacy** | 3 persona prompts, app icon, `PrivacyInfo.xcprivacy` (4 required-reason APIs) | The manifest declares **no collected data**, although crash and performance data go to Sentry and user content goes to xAI/Google. The Archive job only *warns* when prompts or the manifest are missing. | Structure job checks that the file exists. |
| **CI / Build** | 4-job CI; Archive (unsigned + optional signed + dSYM upload); Release (tag); Dependabot for Actions | Lint runs on **changed files only**, which hides 23 latent strict violations. The Simulator job builds but runs no tests. `Package.swift` declares a Sentry dependency that no target uses. `Package.resolved` is not committed (Sentry floats `from: 9.25.0`). CI prefers the "iPhone 16" simulator, although iPhone 16e sims exist on the runner. CI uses **Xcode 26.3**, but the docs say iOS 18 SDK. | — |

---

## 4. Milestones

Conventions: **S** is at most about 150 changed lines and **M** at most about 300. "AppTests" means the app-hosted XCTest target added in M2-T1, which runs inside the *iOS Simulator Build* job. Each task keeps all 4 CI jobs green.

### M0 — In flight (other worker)
**Goal:** land the work already in progress. **Exit:** #135 merged; no `Task.sleep` polling in Forge/Eternal/Diagnostics VMs.

| ID | Task | Files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M0-T1 | Split `EternalView.swift` / `MercuryBrain.swift` under 400 lines | UI/EternalView, ObservatoryPanels/Visuals, App/MercuryBrain* | **Done: merged as #134** (EternalView 260, MercuryBrain 297 lines). Verify only. | — | — |
| M0-T2 | Event-driven refresh for Forge/Eternal/Diagnostics | Core/EventDrivenRefresh.swift, UI/{Forge,Eternal,Diagnostics}ViewModel.swift, Tests/EventDrivenRefreshTests.swift | PR #135 is open and all 4 checks pass. `rg 'Task.sleep' UI/*ViewModel.swift` returns only HomeViewModel (removed in M1). **HUMAN GATE:** owner merges #135. | M | — |

### M1 — Ship-blocker + legacy persona/dashboard cleanup
**Goal:** make AI configurable from the shipping UI and remove all legacy persona/dashboard code. **Exit:** keys can be bound in Codex; no mock text reaches the user; `rg -n 'ContentView|HomeViewModel|SettingsView\b|PersonaDecisionPolicy|TaskKind|QueryIntent|updateTaskContext|CapabilitySurface' --glob '*.swift'` returns nothing; full-repo strict lint is clean.

| ID | Task | Likely files | Acceptance (CI-provable) | Size | Deps |
|---|---|---|---|---|---|
| M1-T1 | Clear the 23 latent strict-lint violations outside UI/ | Services/AI/GrokAPIModels.swift (add CodingKeys), ContextAssembler, Personas/PersonalityState, Intents/IntentDependencies, Core/Models/MemoryItem, Nexus/{NexusState,Signal,DiagnosticEvent,InsightEngine}, Package.swift | `swiftlint lint --strict` on the whole repo reports 0. Grok JSON still encodes `max_tokens` and decodes `finish_reason`/`*_tokens` (`GrokAPIModelsTests` extended). SPM green. | S | — |
| M1-T2 | **Bind provider keys in the Codex** | UI/CodexView.swift, UI/SettingsViewModel.swift | Codex "Covenant" section has SecureFields plus Bind/Unbind for Grok and Gemini, wired to the existing `saveGrokKey`/`saveGeminiKey`/`clear*`. Binding the first key sets `aiServiceEnabled = true`. The Simulator build passes. (Unit tests land in M2-T4.) | S | — |
| M1-T3 | Replace user-visible mock output with an "unbound" state | Services/AI/AIService.swift, App/MercuryBrain.swift, UI/AskView.swift | With no key, or with AI disabled, `ask` throws a typed `AppError.apiKeyMissing` or disabled error, and Ask/Forge/Eternal show "Intelligence unbound — bind a key in the Codex". `MockAIProvider` is used only by tests or an explicit test launch argument. The SPM test `testNoKeyYieldsApiKeyMissing` passes. | S | — |
| M1-T4 | Delete legacy dashboard (`ContentView`, `HomeViewModel`) | UI/ContentView.swift, UI/HomeViewModel.swift, .github/workflows/ci.yml (the structure list requires `UI/ContentView.swift`; replace it with `UI/SanctumView.swift`) | Files removed. Structure job passes with the updated list. Simulator build passes. | S | — |
| M1-T5 | Delete `SettingsView`; rename `SettingsViewModel` → `CodexViewModel`; drop the autonomy shims | UI/SettingsView.swift, UI/SettingsViewModel.swift → CodexViewModel.swift, UI/CodexView.swift | No `SettingsView`, `setPersonaAutonomy` or `personaAutonomyEnabled` symbols remain. Build passes. | S | M1-T2, M1-T4 |
| M1-T6 | Brain-facing surface for Intents (one justified Core protocol) | Core/Protocols/IntelligenceSurface.swift (new: `ask`, `remember`, `snapshot`, `switchAspect`, `statusReport`), App/MercuryBrain.swift (conform), Intents/IntentDependencies.swift, App/DependencyContainer.swift, Tests/IntentsTests.swift (new) | Intents call only `IntelligenceSurface`. SPM tests with a fake surface show `ForcePersona`→`switchAspect`, `CaptureMemory`→`remember`, `QueryNexus`→`ask`. `rg 'personaManager\|aiService' Intents/` is empty. Add the new protocol file to the Structure job's contract list. *(Owner-approved. M3.5 extends this same protocol with memory query/delete and diagnosis methods; no further Core protocols.)* | M | M1-T1 |
| M1-T7 | Aspect vocabulary in Intents/Shortcuts | Intents/PersonaEntity.swift → AspectEntity.swift, Intents/QuicksilverIntents.swift | Titles and phrases say "Aspect" or "Forge/Eternal", with no "Persona" in user-facing strings. At most 10 AppShortcuts. `QueryNexusIntent`'s local keyword classifier is removed (the Brain's `IntentEngine` decides). SPM + build pass. | S | M1-T6 |
| M1-T8 | Remove legacy persona policy/context shims | Personas/PersonaDecisionPolicy.swift, Personas/PersonaContext.swift, Personas/PersonaManager.swift (init params, `updateTaskContext`), App/MercuryBrain.swift call sites, Tests/PersonaManagerTests.swift | Files and legacy tests removed; remaining PersonaManager tests pass. | S | M1-T7 |
| M1-T9 | Remove leftover markers, typealiases, string-ID switching and dead flags | App/CapabilitySurface.swift, UI/VisualState.swift, Memory/MemoryStore.swift (`UserDefaultsMemoryStore`), App/DependencyContainer.swift (`switchPersona*` shims), UI/{Forge,Eternal}ViewModel.swift (`switchPersona(to:"forge")` → `switchAspect(.forge)`), Core/FeatureFlags.swift (unused keys; keep schema migration) | Symbols are gone and tests are updated. SPM + build pass. | S | M1-T5, M1-T8 |
| M1-T10 | Remove the dead AI prompt path | Services/AI/AIService.swift (`complete(userMessage:…)`), ContextAssembler.swift, PromptBuilder.swift, Tests/PromptBuilderTests.swift | `BrainComposition.systemPrompt` is the only prompt assembler. SPM + build pass. | S | M1-T1 |
| M1-T11 | Fold `MercuryVisualTokens` into `PersonaTheme`/`MotionTokens` | UI/MercuryVisualSystem.swift, UI/PersonaTheme.swift, UI/MotionTokens.swift, call sites | `rg 'Color\(red' UI` matches only PersonaTheme.swift. Build passes. | S | — |
| M1-T12 | Docs sync to reality | README.md, Documentation/{SIDESTORE,HARDENING,MERCURY_VISUAL_SYSTEM,ARCHITECTURE}.md, AGENTS.md "Current focus" | No persona switcher, "Settings" or xAI-only steps. CI Xcode is 26.3 (not iOS 18 SDK). Target is iPhone 16e (not iPhone 14). First-run checklist says "Codex → bind keys". Structure job passes. | S | M1-T5 |

**HUMAN GATE HG1 (after M1-T3):** run *Actions → Archive IPA* (Release) on `main`. Install over the existing app in SideStore and confirm it launches to the Sanctum. In the Codex, bind the Grok and Gemini keys and do an Ask round-trip. This also **confirms that the model IDs `grok-4.6` and `gemini-3.7-flash` are accepted by your accounts**. Then bind an invalid Grok key and confirm Gemini answers. Report failures as issues. This is the first device build since 2026-09-18.

### M2 — Test & CI foundation
**Goal:** App-layer behavior is provable in CI, and builds are reproducible. **Exit:** the iOS Simulator Build job runs app-hosted unit tests and a UI smoke test on iPhone 16e; full-repo strict lint is enforced; `Package.resolved` is committed.

| ID | Task | Likely files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M2-T1 | App-hosted unit test target in CI | project.yml (`QuicksilverAppTests`, sources `AppTests/`, host `Quicksilver`), AppTests/SmokeTests.swift, .github/workflows/ci.yml (the *iOS Simulator Build* job adds `xcodebuild test -only-testing:QuicksilverAppTests`; job name unchanged), App/QuicksilverApp.swift (skip `SentrySDK.start` when XCTest is present) | The job runs and passes at least one `@testable import Quicksilver` test. Structure list includes `AppTests/`. | M | M1-T4 |
| M2-T2 | CI simulator destination prefers iPhone 16e | .github/workflows/ci.yml | Log shows "Matched preferred device: iPhone 16e" (16e sims exist on the runner for iOS 18.5/18.6). | S | M2-T1 |
| M2-T3 | Injectable `DependencyContainer` | App/DependencyContainer.swift | New `init(memoryStore:aiProvider:nexus:defaults:)`; the default init is unchanged. An AppTests case builds a container with an in-memory store and a stub provider. | S | M2-T1 |
| M2-T4 | Codex and Ask view-model tests | AppTests/CodexViewModelTests.swift, AppTests/AskViewModelTests.swift | Tests cover: bind/unbind key updates `hasGrokKey` and the provider name; the first bind enables AI; Ask submit persists user and assistant turns; a provider error sets `errorMessage`; the unbound state is shown. | S | M2-T3, M1-T5 |
| M2-T5 | MercuryBrain tests | AppTests/MercuryBrainTests.swift | Tests cover: ask happy path; broker `.deny` → `.warning` + throw; `remember` stores an entity-wide item (`personaScope == nil`); `switchAspect` updates the aspect, the PersonaManager projection and the `personaDidChange` event; visualState passes `.thinking` → `.success` → baseline. | M | M2-T3 |
| M2-T6 | Memory/Forge/Eternal view-model tests | AppTests/{Memory,Forge,Eternal}ViewModelTests.swift | Tests cover: load, clear and export; awaken → aspect; `captureNote` → memory item. | S | M2-T3 |
| M2-T7 | Grok/Gemini HTTP tests via `URLProtocol` stub | Tests/ProviderHTTPTests.swift, Services/AI/*Provider.swift (inject session through `make`) | Tests assert endpoint, headers, model and body shape; 2xx decode; 401/429/500 → `AppError`; malformed JSON; cancellation → `CancellationError`. SPM green. | M | M1-T1 |
| M2-T8 | `SwiftDataMemoryStore` tests | Tests/SwiftDataMemoryStoreTests.swift | With `inMemory: true`, tests cover save/update/delete, `deleteAll(in:)` and metadata round-trip. SPM (macOS 15) green. | S | — |
| M2-T9 | Reproducible dependencies | Package.swift (remove the Sentry dependency no target uses), Package.resolved (commit), project.yml (pin Sentry `exactVersion`) | SPM resolve no longer fetches sentry-cocoa. Simulator build passes with the pinned version. | S | — |
| M2-T10 | Enforce full-repo strict lint | .github/workflows/ci.yml (lint job lints all files) | The SwiftLint job lints the whole repo `--strict` and passes. | S | M1-T1, M1-T9 |
| M2-T11 | XCUITest smoke target | project.yml (`QuicksilverUITests`), UITests/SanctumSmokeTests.swift, App (a `-uitest` launch arg selects an in-memory store, stub AI and no Sentry), ci.yml | CI launches the app, opens each Sanctum destination (Workshop, Planetarium, Archive, Codex, Diagnostics, Ask) and dismisses it. The test passes. | M | M2-T1, M2-T3 |

### M3 — Intelligence robustness (Grok primary, Gemini fallback, Brain)
**Goal:** reliable, private and contextual AI. **Exit:** all provider and Brain behavior is covered by SPM and AppTests; no key appears in any URL; multi-turn works.

| ID | Task | Likely files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M3-T1 | Gemini key moves to the `x-goog-api-key` header | Services/AI/GeminiAIProvider.swift, Tests/ProviderHTTPTests.swift | The test asserts the URL has no `key` query item and the header is set. | S | M2-T7 |
| M3-T2 | Error classification + correct fallback | Core/AppError.swift (`rateLimited`, `unauthorized`, `providerUnavailable`), Services/AI/{AIService,Grok,Gemini}*.swift | Tests: cancellation does **not** invoke the fallback; 401/429/5xx/network on the primary → fallback used; both failing → the last typed error; user-facing descriptions contain no provider details. | S | M2-T7 |
| M3-T3 | Bounded retry for 429/5xx | Services/AI/AIService.swift (or a small `RetryPolicy` in ServicesAI) | At most 1 retry per provider, honoring `Retry-After` up to 5 s. The URLProtocol test counts attempts. Cancellation stops the retry. | S | M3-T2 |
| M3-T4 | Offline fast-fail in the Brain | App/MercuryBrain.swift | When Nexus reports `disconnected`, `ask` skips the cloud providers without a network call and the living status says so (AppTests). After M3.5-T3 it routes to the on-device model; until then, or when on-device is unavailable, it throws `.networkUnavailable`. | S | M2-T5 |
| M3-T5 | Configurable model IDs | Core/AppConfiguration.swift (or an AI config struct), Services/AI/*, UI/CodexView.swift (read-only display) | Model IDs are defined once. Codex shows the active model. Tests assert the configured ID lands in the request body. | S | M2-T7 |
| M3-T6 | Multi-turn history in `AIRequest` | Core/Models/AIRequest.swift (`history: [Message]`), Services/AI/{Grok,Gemini}AIProvider.swift | Grok encodes `messages` in the order system, history, user; Gemini encodes `contents` with `user`/`model` roles. SPM encoding tests pass. | S | M2-T7 |
| M3-T7 | Brain sends the recent conversation within budget | App/MercuryBrain.swift, App/MercuryBrainComposition.swift | `ask` includes the last N (≤ 8) conversation turns, and the broker token estimate includes them. AppTests assert the stub provider receives the history. | S | M3-T6, M2-T5 |
| M3-T8 | Entity-wide Ask history | UI/AskViewModel.swift, Intents (CaptureMemory scope) | History no longer filters by `personaScope`, and aspect is recorded in metadata. AppTests: history survives an aspect switch. | S | M2-T4 |
| M3-T9 | Query-relevant memory retrieval | Memory/MemoryQuery.swift (`text` term-overlap score × `decayedImportance`), App/MercuryBrain.swift | SPM tests: relevant items outrank higher-importance irrelevant ones; decay applies. The Brain passes the query, and chat turns already in history are excluded. | M | M3-T7 |
| M3-T10 | Prompt hygiene for memory/device context | App/MercuryBrainComposition.swift | Memory is emitted inside a delimited "untrusted notes" block and each item is capped at 180 characters (already true). AppTests snapshot the prompt structure. | S | M2-T5 |
| M3-T11 | Wire the Brain's capability surface into `ask` | App/MercuryBrain.swift, App/MercuryBrain+Capabilities.swift | Intent `.remember` → `invoke(.memoryWrite)` stores the note and confirms; `.retrieve` → a memory read is included. AppTests cover both. (Today `invoke` has no callers.) | S | M3-T9 |

**HUMAN GATE HG2 (after M3):** install a new Archive IPA. On device, check: airplane-mode Ask shows the offline message; a 3-turn conversation keeps context; "remember that …" appears in the Archive; responses come from Grok, and from Gemini after unbinding Grok.

### M3.5 — Apple Intelligence & App Intents throughout
**Goal:** Mercury uses the on-device Apple Foundation Model as its private, offline mind, and exposes its memory, aspects and diagnostics to Siri, Spotlight, Shortcuts and Apple Intelligence. Everything goes through `IntelligenceSurface` → `MercuryBrain`. **Exit:**
- With no keys, or offline, on an Apple-Intelligence device, Ask answers on-device.
- Unavailability is explained, and no mock text remains.
- Memory, Aspect and Diagnostics intents/entities have fake-backed SPM tests.
- Memories appear in Spotlight (toggle).
- Snippets render in Mercury style.
- All CI jobs pass with the iOS 18 minimum.

**Build rules for this milestone (CI facts):**
- CI uses Xcode 26.3 (iOS/macOS 26 SDK), so iOS 26 APIs compile. Every use needs `#if canImport(FoundationModels)` plus `@available(iOS 26.0, macOS 26.0, *)` / `if #available`. The deployment floor stays iOS 18 and SPM macOS 15.
- SPM tests run on a macOS 15 runner, where FoundationModels is unavailable at runtime. So the model sits behind a ServicesAI-internal seam (`OnDeviceModelClient`, not a Core protocol) with a fake.
- The simulator job can run the real Tool/intent wrappers on an iOS 26 simulator, where model availability is expected to be `.unavailable`. Real generation is verified only on the phone (HG3).
- `FoundationModels` must be weak-linked for pre-26 devices.
- iOS 27-only APIs are listed under *Deferred* below.

| ID | Task | Likely files | Acceptance (CI-provable) | Size | Deps |
|---|---|---|---|---|---|
| M3.5-T1 | On-device model seam + availability | Services/AI/OnDevice/OnDeviceModelClient.swift (internal protocol + `SystemOnDeviceModelClient` wrapping `SystemLanguageModel.default` / `LanguageModelSession`), Services/AI/OnDevice/OnDeviceAvailability.swift, project.yml (`OTHER_LDFLAGS: -weak_framework FoundationModels` on ServicesAI and the app) | `OnDeviceAvailability` maps `.available`, `.unavailable(.deviceNotEligible / .appleIntelligenceNotEnabled / .modelNotReady / other)` and "OS < 26". SPM tests with a fake client cover each mapping. Builds for iOS 18 floor; `otool -l` on the simulator app in the CI build step shows `LC_LOAD_WEAK_DYLIB` for FoundationModels. | S | M2-T1 |
| M3.5-T2 | `FoundationModelsAIProvider: AIProvider` | Services/AI/OnDevice/FoundationModelsAIProvider.swift, Core/AppError.swift (`onDeviceUnavailable(reason)`, `contentRefused`) | Creates a `LanguageModelSession(instructions:)` per request (history rendered into the prompt) and calls `respond(to:options:)` with `GenerationOptions(temperature:maximumResponseTokens:)`. Maps `GenerationError` cases `exceededContextWindowSize`, `guardrailViolation`/`refusal`, `unsupportedLanguageOrLocale`, `assetsUnavailable` and `rateLimited` to typed `AppError`s, and propagates cancellation. SPM tests via the fake client cover success, each error mapping and cancellation. `isAvailable` reflects T1. | M | M3.5-T1, M3-T2 |
| M3.5-T3 | Routing: on-device replaces the mock for users | Services/AI/AIService.swift, App/MercuryBrain.swift, UI (unbound copy) | Order: Grok → Gemini → on-device. **No keys → on-device; offline → on-device without touching the network.** If on-device is unavailable, a typed error carries the reason and the UI shows "Intelligence unbound — bind a key in the Codex or enable Apple Intelligence". `MockAIProvider` is referenced only from Tests/AppTests and the `-uitest` launch path (`rg MockAIProvider App UI Services` shows only the test hook). SPM and AppTests cover each route. | M | M3.5-T2, M1-T3, M3-T4 |
| M3.5-T4 | On-device context budget + prewarm | App/MercuryBrainComposition.swift, App/MercuryBrain.swift | When the resolved provider is on-device, the Brain builds a **compact** prompt (short instructions, at most 3 memory items, at most 4 history turns, device line). On `exceededContextWindowSize` it retries once with a minimal prompt. `prewarm(promptPrefix:)` is called when the Invocation opens and when availability is `.available`. AppTests assert the compact prompt stays within a character budget and that the retry happens once. | S | M3.5-T3, M3-T7 |
| M3.5-T5 | Codex: on-device mind status | UI/CodexView.swift, UI/CodexViewModel.swift | The "Mind" section shows the on-device state (Available / Apple Intelligence off / Preparing model / Not eligible / Requires iOS 26) and the active route (Grok / Gemini / On-device). AppTests cover the status strings with a fake availability. | S | M3.5-T3, M1-T5 |
| M3.5-T6 | Guided generation: memory distillation | Services/AI/OnDevice/MemoryDistillation.swift (`@Generable struct MemoryDistillation { title; category (@Generable enum mirroring MemoryItem.Category); importance @Guide(.range(0...1)) }`), App/MercuryBrain.swift (remember path) | When on-device is available, `remember` stores the distilled title and category and blends the importance with `MemoryScorer`. Otherwise it falls back to the current behavior. The call goes through `respond(to:generating:)`, and the note text is never sent to cloud providers for this. SPM tests (fake client returns a distillation) and AppTests (unavailable → fallback). | M | M3.5-T2 |
| M3.5-T7 | Guided generation: structured diagnosis | Services/AI/OnDevice/DiagnosisReport.swift (`@Generable` summary / severity enum / up to 3 suggestions), App/MercuryBrain.swift (`diagnose()` on `IntelligenceSurface`), UI/DiagnosticsView.swift | Diagnostics shows the report. When on-device is unavailable, a deterministic report from `InsightEngine`/`NexusState` is used. SPM tests cover the fallback builder; AppTests cover the Brain path with a fake. | M | M3.5-T6, M5-T2 |
| M3.5-T8 | Tool calling: Brain-backed tools for the on-device session | Services/AI/OnDevice/Tools/{RecallMemoryTool,DeviceStateTool}.swift (`Tool` with `@Generable Arguments`; logic in plain functions over Brain-supplied `@Sendable` closures), App/MercuryBrain.swift | At most 3 tools. Tools read only via Brain-provided closures (memory snapshot / NexusState), never the stores directly. SPM tests cover the plain functions. AppTests on the iOS 26 simulator call `call(arguments:)` directly and assert the output. The tools are attached only to the on-device session. | M | M3.5-T4, M3-T9 |
| M3.5-T9 | Discoverable framework intents *(was M5-T4)* | App/QuicksilverAppIntentsPackage.swift, Intents/QuicksilverIntentsPackage.swift (`AppIntentsPackage`) | The app package includes the Intents framework package. The simulator build passes. **Device check in HG3.** | S | M1-T7 |
| M3.5-T10 | Cold-start-safe intents *(was M5-T5)* | App/QuicksilverApp.swift, Intents/IntentDependencies.swift | The surface is configured during `App.init`. An unconfigured state throws a readable dialog ("Open Mercury once"). SPM test. | S | M1-T6 |
| M3.5-T11 | `MemoryEntity` + queries | Intents/Entities/MemoryEntity.swift (`AppEntity`, `DisplayRepresentation` with title/subtitle, `EntityStringQuery` + `suggestedEntities`), Core/Protocols/IntelligenceSurface.swift (+`memories(matching:)`, `memory(id:)`, `deleteMemory(id:)`) | Only user notes and distilled memories are exposed; chat turns are never exposed. SPM tests with a fake surface cover `entities(for:)`, `entities(matching:)` and suggested entities. | S | M3.5-T10, M3-T9 |
| M3.5-T12 | Memory intents on the `.journal` assistant schemas + donations | Intents/MemoryIntents.swift: `@AssistantIntent(schema: .journal.createEntry)`, `.journal.search`, `.journal.deleteEntry` (with `requestConfirmation`); `@AssistantEntity(schema: .journal.entry)` on `MemoryEntity`; replaces `CaptureMemoryIntent`; UI remember paths donate through `IntentDonationManager` | Each intent calls only `IntelligenceSurface`. Delete asks for confirmation. SPM `perform()` tests with a fake cover create, search, delete and the confirmation path. Donations happen only for UI-originated creates (AppTests with a spy). | M | M3.5-T11 |
| M3.5-T13 | Spotlight: memories as `IndexedEntity` | Intents/Entities/MemoryEntity.swift (`IndexedEntity`), App/SpotlightIndexer.swift (EventBus `memoryDidUpdate` → `CSSearchableIndex(name:).indexAppEntities` / `deleteAppEntities(identifiedBy:ofType:)`), UI/CodexView.swift toggle "Memories in Spotlight", Core/FeatureFlags.swift | Index on create/update; delete on delete, clear and retention prune; full reindex on launch. Turning the toggle off calls `deleteAppEntities(ofType:)`. Chat turns are never indexed. AppTests use an indexer spy (index protocol local to the App target) to cover each path. | M | M3.5-T11 |
| M3.5-T14 | Aspect & Diagnostics as App Intents entities | Intents/Entities/AspectAppEnum.swift (`AppEnum`, replaces `AspectEntity` from M1-T7), Intents/Entities/DiagnosticsEntity.swift + `ReportStatusIntent` / `EnterAspectIntent` / `CurrentAspectIntent` | Status returns `ProvidesDialog` (full and supporting strings, in Mercury's voice) built from `IntelligenceSurface.diagnose()` / `statusReport`. SPM tests with a fake cover each intent. | S | M3.5-T7, M3.5-T10 |
| M3.5-T15 | "Open Diagnostics" deep link *(was M5-T6)* | Intents/QuicksilverIntents.swift, App (pending-destination state), UI/SanctumView.swift | The intent sets the pending destination and Sanctum presents Diagnostics. The XCUITest launches with the destination argument and asserts Diagnostics is visible. | S | M2-T11 |
| M3.5-T16 | Ask Mercury intent + Mercury-styled snippets | Intents/AskMercuryIntent.swift (`ProvidesDialog & ShowsSnippetView`), Intents/Snippets/{AnswerSnippet,StatusSnippet}.swift (PersonaTheme tokens, no chat bubble) | Ask goes through `IntelligenceSurface.ask` (so it works on-device when offline or keyless); ReportStatus shows `StatusSnippet`. SPM `perform()` tests cover dialog content with a fake. Snippet views build in the simulator job. | M | M3.5-T14, M3.5-T3 |
| M3.5-T17 | Interactive status snippet (iOS 26) | Intents/Snippets/StatusSnippetIntent.swift (`SnippetIntent`, `ShowsSnippetIntent`, `Button(intent:)` for "Remember this" / "Open Diagnostics") | Behind `@available(iOS 26.0, *)`; on older OSes it degrades to the static snippet from T16. SPM/AppTests cover the snippet intent's `perform()` with a fake. | S | M3.5-T16, M3.5-T15 |
| M3.5-T18 | Shortcuts phrases + Writing Tools | Intents/QuicksilverShortcuts.swift, UI inputs (Forge capture, Eternal observe, Archive add → `.writingToolsBehavior(.complete)`; Invocation → `.limited`; key fields → `.disabled`) | At most 10 `AppShortcut`s (Ask, Remember, Search memories, Status, Enter aspect, Open Diagnostics). Every phrase contains `\(.applicationName)`. `updateAppShortcutParameters()` is called after aspect/memory changes. An SPM test asserts the count and the phrase rule. `rg -c writingToolsBehavior UI` shows each input covered. | S | M3.5-T12, M3.5-T14 |

**HUMAN GATE HG3 (after M3.5):** run on the iPhone 16e, with Apple Intelligence enabled and the English language/region.
- **On-device model:**
  - The Codex shows "On-device: Available".
  - In airplane mode, or with keys unbound, an Invocation is answered on-device.
  - "Remember that …" produces a sensible distilled title and category.
  - Diagnostics shows a structured report.
  - With Apple Intelligence turned off, the Codex shows the reason and the unbound message appears.
- **Siri, Spotlight and Shortcuts:**
  - The Mercury shortcuts and phrases appear in the Shortcuts app.
  - After a force-quit, "Remember this in Mercury" and "Mercury status" succeed from Siri.
  - A remembered note appears in Spotlight, and disappears after it is deleted or the toggle is turned off.
  - The interactive snippet buttons work.
  - "Open Diagnostics" opens Diagnostics.
- **Writing Tools** appears on note inputs.
- **Pre-26 launch check:** with an older test device or simulator, if available, the app launches without FoundationModels.

**Optional / deferred (not v1 tasks):**
- *Controls/widgets* (ControlWidget/WidgetKit) need an extension target. That means extra signing and an extra App ID under SideStore's free-account App ID limit. Revisit after 1.0.
- *Image Playground* and *Visual Intelligence* don't fit an entity that is "a place, not a tool". Not planned.
- *iOS 27-only APIs* (blocked until CI has Xcode 27, then re-plan):
  - the new `LanguageModel` protocol (which could wrap Grok/Gemini and let one `LanguageModelSession` hand off between models);
  - `PrivateCloudComputeLanguageModel` (requires an entitlement, likely unattainable under SideStore re-signing);
  - Dynamic Profiles, `OCRTool`/`BarcodeReaderTool` and the Spotlight search tool;
  - `IndexedEntityQuery`, `SyncableEntity` and `RelevantEntities`;
  - on-screen awareness view annotations;
  - `AppIntentsTesting` (out-of-process intent tests);
  - `.system.searchInApp` (the iOS 27 name for `.system.search`).

### M4 — Memory, data & privacy hardening
**Goal:** durable, bounded, private data, plus trustworthy crash reporting. **Exit:** schema is versioned; growth is capped; Keychain writes are atomic; the manifest is accurate; Sentry is centralized and scrubbed, with an opt-out.

| ID | Task | Likely files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M4-T1 | `SwiftDataMemoryStore` → `@ModelActor` | Memory/SwiftDataMemoryStore.swift | M2-T8 tests still pass. No `ModelContext` is stored in a plain actor. | S | M2-T8 |
| M4-T2 | SwiftData `VersionedSchema` v1 + `SchemaMigrationPlan` | Memory/SwiftDataMemoryStore.swift, Memory/MemorySchema.swift | Container built with the migration plan. SPM test opens the v1 store. | S | M4-T1 |
| M4-T3 | Batch clear | Memory/MemoryManager.swift | `clearAll` uses `deleteAll(in:)` per category and publishes one update. Partial-failure semantics are kept (the existing CHR-30 test passes). | S | M2-T8 |
| M4-T4 | Retention and pruning on launch | Memory/MemoryManager.swift (`applyRetention(now:)`), App/DependencyContainer.swift | Prunes `temporary`/`conversation` items whose decayed importance is below a floor, and caps the total (constants in one place). SPM tests use a fixed `now`. | S | M4-T3 |
| M4-T5 | Surface memory load failures | Memory/MemoryManager.swift (`loadError`), UI/MemoryView.swift | A failed load shows an error row, not an empty list. SPM + AppTests. | S | M2-T6 |
| M4-T6 | Atomic Keychain writes | Core/KeychainStore.swift | `SecItemUpdate`, falling back to `SecItemAdd`, returning a status. AppTests (simulator Keychain) cover set/overwrite/delete. | S | M2-T1 |
| M4-T7 | Accurate Privacy Manifest | PrivacyInfo.xcprivacy, ci.yml Structure (validate plist with `python3 -c plistlib`) | Declares crash data, performance data and other user content (sent to AI providers), not linked and not used for tracking. The plist parses in CI. | S | — |
| M4-T8 | Sentry: errors + hangs only, centralized and scrubbed | App/QuicksilverApp.swift → App/CrashReporting.swift, project.yml (Info.plist key for the DSN) | **Remove performance tracing and profiling**: no `tracesSampleRate`, no `configureProfiling`. `enableMetrics = false` and `enableCaptureFailedRequests = false`. Crash reporting and `enableAppHangTracking` stay on. DSN comes from Info.plist; release/dist come from the bundle version; `beforeSend`/`beforeBreadcrumb` redact via `LoggerService.redact` and strip URL queries; `sendDefaultPii = false`; disabled under XCTest/`-uitest`. AppTests assert the options object (traces/profiling/metrics off, hangs on) and the scrubber. | M | M2-T1, M3-T1 |
| M4-T9 | Crash-reporting opt-out in the Codex | UI/CodexView.swift, Core/FeatureFlags.swift (`crashReporting`), App/CrashReporting.swift | The toggle persists, and Sentry does not start when it is off (AppTests). | S | M4-T8 |
| M4-T10 | Version from the bundle | Core/AppConfiguration.swift | `version`/`build` read from `CFBundleShortVersionString`/`CFBundleVersion`, with the fallback kept for SPM. The Codex "Record" shows the real build. | S | — |
| M4-T11 | Remove memory content from logs | Intents/QuicksilverIntents.swift (`"Memory capture persisted: \(truncated.prefix(60))"`), audit `logger.*` calls | No log line interpolates memory or prompt content (test with `rg` in CI, or code review). | S | M1-T6 |

**HUMAN GATE HG4 (after M4-T9):** confirm the repo secret `SENTRY_AUTH_TOKEN` is set (org `inbetween`, project `quicksilver`). Run the Archive, trigger a test crash (see M6-T3) and confirm a **symbolicated** event arrives. Then turn the opt-out on and confirm no events arrive.

### M5 — Experience completion (Nexus, VisualState, Intents, performance, accessibility)
**Goal:** every shipped surface is complete, responsive, efficient and accessible, and Ask becomes an Invocation. **Exit:** VisualState shows live; animations are cadence-governed; Ask has no bubble-chat UI; the accessibility audit passes in CI. *(Former M5-T4/T5/T6, the intents work, moved to M3.5 as M3.5-T9, T10 and T15. IDs M5-T4..T6 are retired.)*

| ID | Task | Likely files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M5-T1 | Publish insights on the EventBus | Core/EventBus.swift (`insightGenerated`), Nexus/NexusCoordinator.swift, UI/DiagnosticsViewModel.swift | Remove the Diagnostics 60 s fallback timer. SPM test: an insight → an event. | S | M0-T2 |
| M5-T2 | Health score includes thermal and storage | Nexus/NexusCoordinator.swift | Weighted score. SPM tests: serious thermal or storage under 5% lowers the score. | S | — |
| M5-T3 | Live VisualState propagation | UI/*ViewModel.swift, UI/SanctumView.swift | Views read `container.brain.visualState` through Observation, not snapshot copies. AppTests: during `ask`, the Sanctum-facing state is `.thinking`. | S | M2-T5 |
| M5-T7 | Animation cadence policy | UI/MotionTokens.swift (`AnimationCadence`), UI/{QuicksilverCoreView,MercuryVisualSystem,AmbientLayer,ForgeView,ObservatoryVisuals}.swift | Every `TimelineView` takes the policy: paused when scenePhase is not active, when covered by a realm, or under Reduce Motion; 15 fps in Low Power Mode. AppTests unit-test the policy. `rg 'paused: false' UI` is empty. | M | M2-T1 |
| M5-T8 | Tokenize literals in ForgeView and QuicksilverCoreView | UI/ForgeView.swift, UI/QuicksilverCoreView.swift, PersonaTheme/MotionTokens | Literal count (opacity/padding/frame/radius/duration) under 5 per file. Build + UI smoke pass. | M | M1-T11 |
| M5-T9 | Tokenize literals in Eternal, Observatory, Sanctum and RuneGlyph | UI/{EternalView,ObservatoryPanels,ObservatoryVisuals,SpatialSanctum,RuneGlyph}.swift | Same criterion. | M | M1-T11 |
| M5-T10 | Accessibility pass A: Sanctum, Forge, Eternal | the related UI files | Labels/hints on glyphs and gateways; decorative layers `accessibilityHidden`; fixed `.system(size:)` fonts replaced with Dynamic Type styles. XCUITest `performAccessibilityAudit()` on these screens passes. | M | M2-T11 |
| M5-T12 | Ask → "Invocation" surface: layout | UI/AskView.swift → UI/InvocationView.swift, UI/AskViewModel.swift, PersonaTheme/MotionTokens | No bubbles, no chat list and no "Provider:" chrome. The Quicksilver core is the focal point: the current utterance and response render as an inscription around the presence, and earlier exchanges are reachable as "Echoes" (opening the Archive filtered to conversation). The input uses Writing Tools `.limited`. Tokens only (no literals). AppTests: VM keeps the full history while the view shows only the current exchange. UI smoke test updated. | M | M2-T11, M3-T8 |
| M5-T13 | Invocation: presence states, motion, accessibility | UI/InvocationView.swift, UI/QuicksilverPresenceView.swift | The core's VisualState drives listening/thinking/speaking; streaming or progressive reveal of the response honors Reduce Motion; the on-device vs. cloud source is shown as a subtle glyph, not a label. VoiceOver reads each exchange as one element. `performAccessibilityAudit()` passes on the Invocation surface. | M | M5-T12, M5-T3 |
| M5-T11 | Accessibility pass B: Invocation, Archive, Codex, Diagnostics | the related UI files | Same audit passes for these destinations and runs in CI. | M | M5-T10, M5-T13 |

**HUMAN GATE HG5 (after M5-T11):** judge the Invocation redesign on the phone ("a place, not a chat"). Then run VoiceOver across all destinations, with the largest Dynamic Type and Reduce Motion on. Then do a battery/thermal soak: 20 min in the Sanctum in the foreground plus 1 h in the background, and compare Settings → Battery. Report anything abnormal.

### M6 — Release readiness (v1.0.0)
**Goal:** a trustworthy release pipeline and documentation for 1.0.0. **Exit:** the Archive job fails hard on missing essentials; CHANGELOG and release checklist exist; version is 1.0.0; all human gates are signed off.

| ID | Task | Likely files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M6-T1 | Harden the Archive checks | .github/workflows/archive.yml | Missing persona prompts or PrivacyInfo becomes an **error**. Verify `Sentry.framework` is embedded, and that Info.plist version/build match `project.yml`. (Workflow change only; the owner runs it in HG6.) | S | M4-T10 |
| M6-T2 | Document dormant release paths | README.md, Documentation/SIDESTORE.md (docs only; **do not modify** codemagic.yaml, fastlane/ or release.yml) | README states that Codemagic, Fastlane and the TestFlight step are dormant and that SideStore is the only supported path. Structure job passes. | S | M1-T12 |
| M6-T3 | Diagnostic test-event action | UI/CodexView.swift ("Record" section), App/CrashReporting.swift | A "Send diagnostic event" button (and a test crash behind a confirm, Release included) exists for HG4. AppTests cover the action with a stub. | S | M4-T8 |
| M6-T4 | CHANGELOG | CHANGELOG.md | Entries from 0.2.0 (build 7) to now, generated from merged PRs. | S | — |
| M6-T5 | Owner release checklist | Documentation/RELEASE.md, README link | Lists HG1–HG7 with steps and pass criteria. | S | M1-T12 |
| M6-T6 | Bump to 1.0.0 | project.yml (`MARKETING_VERSION 1.0.0`, `CURRENT_PROJECT_VERSION`+1), docs | Archive banner shows 1.0.0. All 4 CI jobs are green. | S | all above |

**HUMAN GATE HG6:** run *Archive IPA* (Release) for 1.0.0 and install it over the previous build. Confirm memory and keys persist. Wait through or force a SideStore 7-day refresh and confirm data persists. Run the full first-run checklist.
**HUMAN GATE HG7:** final sign-off. Tag `v1.0.0` (this triggers `release.yml`). Merge decisions stay with the owner (AGENTS.md autonomy policy).

---

## 5. Risks

1. **iOS 27 SDK gap.** CI's Xcode 26.3 has no iOS 27 SDK, so the newest Apple Intelligence APIs can't be adopted or CI-verified yet (see M3.5 *Deferred*).
2. **On-device model isn't testable in CI.** Model generation quality and availability are verified only on the phone (HG3). CI verifies mapping, routing, prompts and tools with fakes.
3. **Weak linking.** A missing `-weak_framework FoundationModels` would crash pre-iOS-26 launches. M3.5-T1 checks the load command.
4. **Siri/Apple Intelligence rollout.** Assistant-schema behavior in Siri depends on OS rollout, language and region. Shortcuts/Spotlight/snippets work regardless.
5. **Unverified model IDs.** `grok-4.6` and `gemini-3.7-flash` are hard-coded, and a wrong ID fails every request. Only HG1 can prove them.
6. **App Intents in a framework.** Shortcuts discovery depends on `AppIntentsPackage` wiring (M3.5-T9). CI can only prove that it compiles; HG3 proves discovery.
7. **Xcode 26.3 on CI, iOS 27 on device.** Builds run in compatibility mode on iOS 27, and iOS 27 SDK behavior is untested until runners ship Xcode 27. The docs' "iOS 18 SDK" claim is already wrong (M1-T12).
8. **CI time and flakiness.** Adding app-hosted tests and XCUITest to the Simulator job (M2-T1, M2-T11) adds minutes and simulator flakiness. Keep UI tests to smoke + audit only.
9. **SwiftData schema change without a migration plan** could wipe or crash memory. Land M4-T2 before any `MemoryEntry` change.
10. **Concurrent workers.** M0/M1 touch the same files as the other worker (VMs, Brain). Run the backlog strictly in order.

## 6. Open product questions (owner only)

All six earlier questions are answered (see *Owner decisions* at the top). One small question remains:
- **Q7 — Spotlight default:** should memories be indexed in Spotlight **on by default** (user notes only, never chat), with the Codex toggle to turn it off? M3.5-T13 assumes on by default unless you say otherwise.

## 7. Task count

| Milestone | Tasks |
|---|---|
| M0 In flight | 2 (1 done) |
| M1 Ship-blocker + legacy cleanup | 12 |
| M2 Test & CI foundation | 11 |
| M3 Intelligence robustness | 11 |
| M3.5 Apple Intelligence & App Intents | 18 (3 moved from M5) |
| M4 Memory, data & privacy | 11 |
| M5 Experience completion | 10 (3 moved out, 2 Ask tasks added) |
| M6 Release readiness | 6 |
| **Total** | **81** (80 open) + 7 human gates (HG1–HG7) and the #135 merge |

## 8. Apple APIs chosen (researched 2026-09-25)

| Area | API (min OS) | Docs |
|---|---|---|
| On-device model | `SystemLanguageModel.default`, `.availability` / `UnavailableReason` (iOS 26) | https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel |
| Sessions | `LanguageModelSession(instructions:)`, `respond(to:options:)`, `prewarm(promptPrefix:)`, `GenerationOptions`, `GenerationError` (iOS 26) | https://developer.apple.com/documentation/foundationmodels/languagemodelsession |
| Guided generation | `@Generable`, `@Guide`, `respond(to:generating:)` (iOS 26) | https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation |
| Tool calling | `Tool` (`name`, `description`, `@Generable Arguments`, `call(arguments:)`) (iOS 26) | https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling |
| Entities / Spotlight | `AppEntity`, `EntityStringQuery`, `IndexedEntity` + `CSSearchableIndex.indexAppEntities` (iOS 18) | https://developer.apple.com/documentation/appintents/making-app-entities-available-in-spotlight |
| Siri / Apple Intelligence | `@AssistantIntent(schema: .journal.createEntry / .search / .deleteEntry)`, `@AssistantEntity(schema: .journal.entry)` | https://developer.apple.com/documentation/appintents/assistantschemas/journalintent |
| Donations | `IntentDonationManager` | https://developer.apple.com/documentation/appintents/intentdonationmanager |
| Snippets | `ShowsSnippetView`; interactive `SnippetIntent` / `ShowsSnippetIntent` + `Button(intent:)` (iOS 26) | https://developer.apple.com/documentation/appintents/snippetintent · WWDC25 "Explore new advances in App Intents" https://developer.apple.com/videos/play/wwdc2025/275/ |
| Framework intents | `AppIntentsPackage` (iOS 17) | https://developer.apple.com/documentation/appintents/appintentspackage |
| Writing Tools | `writingToolsBehavior(_:)` (iOS 18) | https://developer.apple.com/documentation/swiftui/view/writingtoolsbehavior(_:) |
| Deferred (iOS 27 SDK) | Foundation Models 2026 (`LanguageModel` protocol, PCC, Dynamic Profiles, OCR/Spotlight tools); App Intents 2026 (`IndexedEntityQuery`, `SyncableEntity`, `RelevantEntities`, on-screen awareness); `AppIntentsTesting` | https://developer.apple.com/videos/play/wwdc2026/241/ · https://developer.apple.com/videos/play/wwdc2026/345/ · https://developer.apple.com/videos/play/wwdc2026/343/ · https://developer.apple.com/documentation/appintentstesting |
