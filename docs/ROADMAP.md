> **Living document.** This is the production roadmap to Quicksilver 1.0. Update it in the same PR as the change that affects it: tick tasks, record owner decisions, and adjust milestones as evidence changes. Task IDs are stable; retired IDs are noted, not reused.

# Quicksilver (Mercury) — Roadmap to Production-Ready

Repo: `cknowlesbadluck/QuicksilverV1` @ `main` `43cdb47` (2026-09-25). Evidence comes from a fresh clone, the docs, `project.yml`/`Package.swift`/workflows, the last ~80 commits, PRs #76–#135, issue #57, CI logs, and a full-repo SwiftLint 0.65.1 `--strict` run. Each task is sized as one PR and is verified by **Quicksilver CI** (Structure & Contracts, SwiftLint, SPM Unit Tests, iOS Simulator Build). **HUMAN GATE** items are for the owner, not the build loop.

**Scope:** distribution is **SideStore only**, using the unsigned IPA from *Archive IPA* (README/AGENTS/SIDESTORE.md). Fastlane, Codemagic and the TestFlight step in `release.yml` stay **dormant, not deleted** (owner decision). Localization is out of scope for the single English-speaking owner (`developmentLanguage: en`; the repo has no string catalogs).

## Owner decisions (2026-09-25)
1. **Integration Fabric** (`Nexus/Integration/*`) stays **dormant for v1**, with no tasks. Revisit after 1.0.
2. **Ask** is redesigned before 1.0 into a non-chat "Invocation" surface (M5-T12, M5-T13).
3. **Forge/Eternal:** today's depth is enough for v1.
4. **Sentry** sends **errors and hangs only**. Tracing, profiling, metrics and failed-request capture are off (M4-T8).
5. **codemagic.yaml / fastlane / TestFlight** stay dormant and are documented as such (M6-T2).
6. **Intents** route through `MercuryBrain` via one small Core protocol, `IntelligenceSurface` (M1-T6).
7. **New requirement:** adopt Apple Intelligence frameworks and App Intents throughout (new **M3.5**).
8. **AI architecture, free options only (no paid services).** Mercury's identity, memory and state live **on the device** and are the source of truth; models are interchangeable. On-device first (Apple Foundation Models, on-device speech, on-device embeddings). Cloud calls go through **one small gateway Christopher owns** on a free tier, which holds provider keys, selects models, fails over, rate-limits and streams one format. Only providers with a genuine free API tier are used. Grok/xAI is optional and used only if Christopher adds his own credits. App Intents double as the model's tools. Sensitive data stays on the device. M3 is reworked for this; picks and free limits are in **section 9**.

---

## 1. Definition of production-ready (checklist)

- [ ] **CI:** all 4 CI jobs are green on `main`. SwiftLint `--strict` covers the **whole repo**, not only changed files. App-layer logic (MercuryBrain, view models) is unit-tested in CI. A UI smoke test plus an accessibility audit runs on the iPhone 16e simulator.
- [ ] **Install:** a fresh *Archive IPA* (Release) installs through SideStore on the owner's iPhone 16e / iOS 27. It launches to the Sanctum, and data and keys survive the 7-day refresh and a reinstall over the existing app.
- [ ] **AI (free-only architecture):** the device is the source of truth; no provider key is stored in the app. Cloud requests go only to the owner's **Mercury Gateway** (Cloudflare Workers Free), bound in the Codex as URL + device token (Keychain only, never in URLs, logs or Sentry). The gateway holds the provider keys, picks the model from a routing config, fails over (before the first streamed token only), enforces per-provider daily budgets under the free limits, and streams one event format. Responses stream in the app, with timeouts and user cancellation (cancel never triggers failover). Offline, unbound, gateway failure or budget exhausted → the on-device model answers, or a clear message appears. No mock text ever reaches the user. A fake provider covers all of this in CI, and an eval harness has compared the candidate models on the Forge/Eternal prompts.
- [ ] **Cloud privacy:** one choke point (`CloudContextPolicy`) builds every cloud payload: the question plus trimmed relevant context. Raw diagnostics and private memories never leave the device. Routes to providers that train on free-tier prompts get the minimal level (no memories, no device line).
- [ ] **Brain:** conversation, Forge, Eternal and Intents all go through `MercuryBrain`. Multi-turn context is sent. Memory retrieval uses on-device embeddings and a local vector index and is relevant to the query. `.remember`/`.retrieve` intents act on memory. VisualState changes (thinking/speaking/warning) show in the UI.
- [ ] **Memory:** SwiftData store with a versioned schema, `@ModelActor` isolation and bounded growth (retention/pruning). Clear, export and load errors show in the UI. Memory is entity-wide, not scoped per persona.
- [ ] **Architecture:** no legacy persona/dashboard code (ContentView/HomeViewModel/SettingsView/PersonaDecisionPolicy/TaskKind shims, marker files, typealiases). Aspect vocabulary only. `PersonaTheme` + `MotionTokens` are the only token sources.
- [ ] **On-device intelligence:** a FoundationModels provider sits behind `AIProvider` and is gated by `#available(iOS 26.0, *)` and `SystemLanguageModel.default.availability`. It answers when you are offline or have no keys, and replaces the mock provider for users. When Apple Intelligence is unavailable, the app says why. Memory distillation and diagnosis use guided generation (`@Generable`). The on-device session can recall memory and device state through tools, and those tools read through the Brain.
- [ ] **App Intents throughout:** Memory, Aspect and Diagnostics are exposed as App Entities/Enums with queries. Memory intents adopt the `.journal` assistant schemas. Memories are indexed in Spotlight (`IndexedEntity`), with a Codex toggle. Ask/Status intents return Mercury-styled snippets, and an iOS 26 interactive snippet is included. All intents go through `IntelligenceSurface` → `MercuryBrain`, work from a cold start, and have fake-backed unit tests. "Open Diagnostics" opens Diagnostics. Shortcuts phrases are discoverable (at most 10).
- [ ] **System text features:** Writing Tools behavior is set deliberately on every text input.
- [ ] **Voice:** voice input is transcribed on the device (SpeechAnalyzer on iOS 26+, on-device-only SFSpeechRecognizer before that); audio never leaves the phone.
- [ ] **Actions:** one Brain action registry backs both App Intents (Siri/Shortcuts) and the on-device model's tools.
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
- **Latent lint debt.** Cleared outside UI/ by M1-T1 (was 23–26 strict violations; full-repo `--strict` is clean outside Tests/ which stay excluded).
- **Stale docs.** They claim an iOS 18 SDK, a persona switcher and an iPhone 14 target.
- **No recent device build.** The last *Archive IPA* run was 2026-09-18 21:57 ET, before the aspect architecture and Sanctum work.
- **Cloud AI is paid-only and keys live in the app.** Grok needs paid credits, the Gemini key sits in the URL, and there is no gateway, streaming, cancellation or fake provider. The owner's free-only decision (Owner decision 8) replaces this with the gateway architecture in M3.
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
| M0-T2 | Event-driven refresh for Forge/Eternal/Diagnostics | Core/EventDrivenRefresh.swift, UI/{Forge,Eternal,Diagnostics}ViewModel.swift, Tests/EventDrivenRefreshTests.swift | ✅ Merged #135. `rg 'Task.sleep' UI/*ViewModel.swift` returns only HomeViewModel (removed in M1). | M | — |

### M1 — Ship-blocker + legacy persona/dashboard cleanup
**Goal:** make AI configurable from the shipping UI and remove all legacy persona/dashboard code. **Exit:** keys can be bound in Codex; no mock text reaches the user; `rg -n 'ContentView|HomeViewModel|SettingsView\b|PersonaDecisionPolicy|TaskKind|QueryIntent|updateTaskContext|CapabilitySurface' --glob '*.swift'` returns nothing; full-repo strict lint is clean.

| ID | Task | Likely files | Acceptance (CI-provable) | Size | Deps |
|---|---|---|---|---|---|
| M1-T1 | Clear the 23 latent strict-lint violations outside UI/ | Services/AI/GrokAPIModels.swift (add CodingKeys), ContextAssembler, Personas/PersonalityState, Intents/IntentDependencies, Core/Models/MemoryItem, Nexus/{NexusState,Signal,DiagnosticEvent,InsightEngine}, Package.swift | `swiftlint lint --strict` on the whole repo reports 0. Grok JSON still encodes `max_tokens` and decodes `finish_reason`/`*_tokens` (`GrokAPIModelsTests` extended). SPM green. | S | — |
| M1-T2 | **Bind provider keys in the Codex** *(interim until the gateway is live; M3-T6 replaces this with gateway URL + token and M3-T22 removes the key fields)* | UI/CodexView.swift, UI/SettingsViewModel.swift | Codex "Covenant" section has SecureFields plus Bind/Unbind for Gemini (free AI Studio key) and optional Grok, wired to the existing `saveGrokKey`/`saveGeminiKey`/`clear*`. Binding the first key sets `aiServiceEnabled = true`. The Simulator build passes. (Unit tests land in M2-T4.) | S | — |
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
| M1-T13 | Interim: Gemini key moves to the `x-goog-api-key` header *(was M3-T1)* | Services/AI/GeminiAIProvider.swift, Tests (request-building test) | A test asserts the URL has no `key` query item and the header is set. Needed before HG1 because failed-request capture in Sentry is still on. | S | M1-T1 |

**HUMAN GATE HG1 (after M1-T3 and M1-T13):** run *Actions → Archive IPA* (Release) on `main`. Install over the existing app in SideStore and confirm it launches to the Sanctum. In the Codex, bind a **free** Gemini key (Google AI Studio, in a project with **no billing enabled**) and do an Ask round-trip; this also confirms that `gemini-3.7-flash` is accepted. Grok is optional: bind it only if you already have xAI credits. Interim caveat: until M3 lands, the app talks to Gemini directly with full context, and the free tier may use prompts for training with human review, so avoid sensitive notes until M3-T11/M3-T22. Report failures as issues. This is the first device build since 2026-09-18.

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

### M3 — Mercury Gateway & free cloud intelligence
**Goal:** the device stays the source of truth, and the cloud becomes a swappable, free, private helper behind one gateway Christopher owns (Owner decision 8; picks and limits in section 9). **Exit:**
- The app holds no provider keys, only the gateway URL and device token.
- Responses stream, time out and cancel cleanly.
- A fake provider covers the app and gateway paths in CI.
- Every cloud payload passes `CloudContextPolicy`.
- Memory retrieval uses on-device embeddings.
- The eval harness has been run against the candidate models, and HG2–HG4 are signed off.

*Old M3 IDs are retired and remapped: T1 → M1-T13; T2 + T3 → M3-T5; T4 → M3-T7; T5 → M3-T4; T6 → M3-T8; T7 → M3-T9; T8 → M3-T10; T9 → M3-T14; T10 → M3-T12; T11 → M3.5-T20.*

**Build rules:**
- The gateway lives in **`gateway/`** in this repo, as a TypeScript Cloudflare Worker. This doesn't break CI:
  - the Structure job only checks for listed files/dirs;
  - SwiftLint only lints `*.swift`;
  - the SPM targets use explicit paths.
- Gateway tests run as an extra **step** in the *Structure & Contracts* job, so the four job names (and any required-check names) stay the same.
- Real provider calls never run in CI. CI uses the fake upstream on the gateway side and `FakeStreamingProvider` in the app.
- Agents never create accounts, deploy, add secrets or enable anything paid. Those are HG2–HG3.

**App side**

| ID | Task | Likely files | Acceptance (CI-provable) | Size | Deps |
|---|---|---|---|---|---|
| M3-T1 | Streaming + cancellation in the provider contract, plus a fake provider | Core/Protocols/AIProvider.swift (add `stream(_:) -> AsyncThrowingStream<AIStreamEvent, Error>`, with a default that wraps `complete`), Core/Models/AIStreamEvent.swift (`meta(route, model, trainsOnPrompts)`, `delta(String)`, `done(usage)`), Services/AI/FakeStreamingProvider.swift (scripted events, delays and errors; used by SPM, AppTests and `-uitest`) | This extends the existing protocol; no new Core protocol. Cancelling the consuming task terminates the stream through `onTermination` and cancels the underlying work. SPM tests cover ordered deltas, a scripted error mid-stream and cancellation within 100 ms. | M | M2-T7 |
| M3-T2 | Gateway wire protocol v1 + shared fixtures | docs/GATEWAY_PROTOCOL.md, gateway/fixtures/*.json / *.sse, Tests/GatewayProtocolTests.swift | Endpoints: `POST /v1/chat` (task tier, messages, **kind-tagged** context blocks (`history`, `summary`, `memory`, `device`), privacy level, max tokens) → `text/event-stream` events `meta` / `delta` / `done` / `error`, with typed codes `unauthorized`, `rate_limited` (+ `retryAfter`), `budget_exhausted`, `upstream_unavailable`, `bad_request` and `timeout`; `GET /v1/config`; `GET /v1/health`. Auth is `Authorization: Bearer <device token>`, never a query string. Swift decoder tests replay every fixture. | S | M3-T1 |
| M3-T3 | `GatewayAIProvider` (SSE client) | Services/AI/Gateway/GatewayAIProvider.swift, Services/AI/Gateway/SSEParser.swift, Tests/GatewayAIProviderTests.swift | Uses `URLSession.bytes(for:)` and parses the SSE line by line. The device token comes from Keychain. Timeouts come from the routing config (defaults: connect 10 s, first event 20 s, idle 15 s, total 90 s). `URLProtocol`-stub tests replay the fixtures: happy path, mid-stream `error`, first-event timeout, 401, 429 with `retryAfter`, and cancellation (the request is cancelled and no further deltas arrive). | M | M3-T2 |
| M3-T4 | Routing config *(replaces old T5 "configurable model IDs")* | Core/Models/AIRoutingConfig.swift (Codable: task kinds → `.onDevice` / `.cloud(tier)`; per-tier display model, `trainsOnPrompts`, context level; timeouts; retry), Resources/ai-routing.default.json, Services/AI/Gateway/RoutingConfigStore.swift, UI/CodexView.swift (read-only active route + model) | Bundled default, refreshed from `GET /v1/config` and cached in Application Support. It is validated, falls back to the bundled copy on any error, and never contains keys. Models and prompts change on the gateway without an app rebuild. SPM tests cover decode, the invalid → bundled fallback and cache use. | M | M3-T3 |
| M3-T5 | Error classification + client fallback *(old T2 + T3)* | Core/AppError.swift (`rateLimited(retryAfter)`, `unauthorized`, `providerUnavailable`, `budgetExhausted`, `timedOut`), Services/AI/AIService.swift | Cancellation never falls back or retries. Gateway 429 / 5xx / timeout before the first delta / network error → at most 1 retry (honoring `retryAfter` up to 5 s), then on-device (after M3.5-T3) or a typed error. A failure after the first delta keeps the partial text, marked incomplete, with no silent model switch. User-facing text names no provider. SPM tests cover each path with the fake. | S | M3-T3 |
| M3-T6 | Codex: bind the gateway | UI/CodexView.swift, UI/CodexViewModel.swift, Core/KeychainStore.swift keys | SecureField for the device token plus a URL field (https only), a "Test connection" button (`/v1/health`) and Unbind. Binding enables AI. AppTests with the stub cover bind, invalid URL, health failure and unbind. | S | M3-T3, M1-T5 |
| M3-T7 | Offline fast-fail in the Brain *(old T4)* | App/MercuryBrain.swift | When Nexus reports `disconnected`, `ask` skips the gateway without a network call and the living status says so (AppTests). After M3.5-T3 it routes to on-device; until then it throws `.networkUnavailable`. | S | M2-T5 |
| M3-T8 | Multi-turn history in `AIRequest` and the gateway request *(old T6)* | Core/Models/AIRequest.swift (`history: [Message]`), Services/AI/Gateway/GatewayRequest.swift | Encodes system, history and user in order, per protocol v1. SPM encoding test against a fixture. | S | M3-T2 |
| M3-T9 | Brain sends the recent conversation within budget *(old T7)* | App/MercuryBrain.swift, App/MercuryBrainComposition.swift | Includes the last N (≤ 8) turns, and the broker token estimate includes them. AppTests assert the fake receives the history. | S | M3-T8, M2-T5 |
| M3-T10 | Entity-wide Ask history *(old T8)* | UI/AskViewModel.swift, Intents (CaptureMemory scope) | History no longer filters by `personaScope`, and the aspect is recorded in metadata. AppTests: history survives an aspect switch. | S | M2-T4 |
| M3-T11 | **Cloud privacy policy** (single choke point) | Services/AI/CloudContextPolicy.swift, App/MercuryBrain.swift, Memory metadata `private` flag (metadata only; no schema change) | `.standard`: the question, ≤ 4 recent turns (or the on-device summary from M3.5-T21), ≤ 3 relevant memories each trimmed to 180 characters, and a coarse device line ("battery low"). `.minimal` is **forced for any tier with `trainsOnPrompts`**: the question and ≤ 2 turns only, with no memories and no device line. Never sent at any level: raw diagnostics / Nexus metrics, memories marked private, identifiers, keys. AppTests snapshot the exact outgoing payload per level. An SPM test proves a `trainsOnPrompts` tier can't receive `.standard`. Every block is kind-tagged so the gateway can redact per candidate on failover (M3-T20). | M | M3-T9, M3-T4 |
| M3-T12 | Prompt hygiene for memory/device context *(old T10)* | App/MercuryBrainComposition.swift | Memory goes in a delimited "untrusted notes" block, each item capped at 180 characters. AppTests snapshot the structure. | S | M2-T5 |
| M3-T13 | On-device embeddings + local vector index | Memory/Embedding/{Embedder,EmbeddingIndex}.swift | `NLContextualEmbedding` (iOS 17; assets via `requestAssets`), mean-pooled and L2-normalized. Falls back to `NLEmbedding.sentenceEmbedding(for: .english)`, then to term overlap. Vectors live in a **rebuildable sidecar file** in Application Support, keyed by memory id and embedding revision, so there is no SwiftData schema change. Brute-force cosine search (fine at the M4-T4 cap). SPM tests use a fake embedder: ranking, rebuild on revision change, delete. | M | M2-T8 |
| M3-T14 | Query-relevant retrieval *(old T9)* | Memory/MemoryQuery.swift, App/MercuryBrain.swift, index updates on `memoryDidUpdate` | Score = cosine × `decayedImportance` (term overlap when no embedder). Chat turns already in history are excluded. SPM tests: a relevant item outranks a more important but irrelevant one, and decay applies. | M | M3-T13, M3-T9 |

**Gateway side (`gateway/`, TypeScript, Cloudflare Workers Free)**

| ID | Task | Likely files | Acceptance (CI-provable) | Size | Deps |
|---|---|---|---|---|---|
| M3-T15 | Scaffold the Worker + CI step | gateway/{package.json, package-lock.json, tsconfig.json, wrangler.toml, src/index.ts, test/health.test.ts, README.md}, .github/workflows/ci.yml (Structure job gains a `npm ci && npm test` step in `gateway/`) | `wrangler.toml` has **no paid bindings**, `workers_dev = true`, and observability that logs metadata only (never request/response bodies). `GET /v1/health` works. The README has Christopher's deploy steps for HG2. All 4 CI jobs stay green with the same names. | S | — |
| M3-T16 | Auth, budgets, rate limits | gateway/src/{auth,limits}.ts, gateway/config/routing.json (`dailyBudget` per candidate) | Bearer `DEVICE_TOKEN` secret with a constant-time compare. Per-token RPM limit. A per-candidate daily request budget kept **below** that provider's free limit; when it is exhausted, the gateway returns a typed `budget_exhausted` event and the app goes on-device. Uses the Workers Rate Limiting binding only if it's available on Workers Free (verify when implementing); otherwise best-effort in-isolate counters. No per-request KV writes. Vitest covers each case. | S | M3-T15 |
| M3-T17 | Unified stream + fake upstream | gateway/src/{stream,providers/fake}.ts | Emits protocol v1 events. The fake provider is deterministic, with scripted errors and delays, and is used by tests and by a local `FAKE_MODE`. A parity test checks the output against `gateway/fixtures`. | S | M3-T15, M3-T2 |
| M3-T18 | Adapters: OpenAI-compatible (Groq) + Gemini | gateway/src/providers/{openaiCompatible,gemini}.ts | OpenAI-compatible streaming via a base URL covers Groq, and xAI / OpenRouter / Mistral later if ever enabled. Gemini uses `streamGenerateContent?alt=sse` with the key in the `x-goog-api-key` header. Upstream chunks map to v1 events, and upstream 401 / 429 (`retry-after`) / 5xx map to typed codes. Tests use recorded fixture streams (no network). | M | M3-T17 |
| M3-T19 | Adapter: Workers AI (`env.AI`) | gateway/src/providers/workersAI.ts, wrangler.toml `[ai]` binding | Streams from a Workers AI text model and maps to v1 events. A "daily free allocation exceeded" response maps to `budget_exhausted`. Vitest uses a mocked binding. | S | M3-T17 |
| M3-T20 | Router: selection, failover, timeouts, cancellation, `/v1/config` | gateway/src/router.ts, gateway/config/routing.json | Each tier has an ordered candidate list (provider, model, `trainsOnPrompts`, `dailyBudget`, `maxOutputTokens`). Failover happens on 429 / 5xx / upstream first-byte timeout **only before the first delta**. A client abort cancels the upstream request through `AbortController`. A candidate whose secret is missing is skipped, which makes xAI optional. **Per-candidate redaction:** before each attempt, the router strips the context blocks that candidate's level doesn't allow (a `trainsOnPrompts` candidate gets `.minimal`: question + last 2 turns; no `memory`, `device` or `summary` blocks), so failover can never widen disclosure. `GET /v1/config` returns client-safe routing only. Vitest with the fake covers failover order, no failover after the first delta, abort propagation, a skipped optional provider, and **the exact payload Gemini receives after a Groq → Gemini failover** (no memory/device/summary blocks). | M | M3-T16, M3-T18, M3-T19 |
| M3-T21 | Model evaluation harness | gateway/eval/{run.ts, cases/forge.json, cases/eternal.json, README.md}, `npm run eval` | Runs the Forge and Eternal cases (built from the bundled persona prompts, in standard and minimal context variants) against the candidates listed in `--candidates`. It goes through the router locally, with keys taken **from the developer's own environment** (never committed). It records first-token and total latency, output length, errors, and rule checks (stays in aspect voice, no chat-assistant phrasing, within the length budget), and writes `gateway/eval/results/<date>.md`. CI runs it only against the fake provider, as a smoke test. | M | M3-T20 |

**HUMAN GATE HG2 — gateway account + deploy (any time after M3-T15; Christopher only).**
1. Create a Cloudflare account on **Workers Free**. No payment method is needed. **Do not** enable Workers Paid or any paid add-on.
2. From `gateway/`, run `npx wrangler login` then `npx wrangler deploy`, as in `gateway/README.md`.
3. Note the `*.workers.dev` URL.

Agents must not create the account, deploy or enable anything.

**HUMAN GATE HG3 — provider keys as gateway secrets (after M3-T20; Christopher only).**
1. **Groq:** create a key on the **Free** plan, with no payment method. Optionally enable Zero Data Retention in Data Controls.
2. **Gemini:** create a Google AI Studio key in a project **without billing**. Unpaid use is free-tier, and the free tier uses prompts for training with human review; the router gives it minimal context.
3. Run `npx wrangler secret put` for `GROQ_API_KEY`, `GEMINI_API_KEY` and `DEVICE_TOKEN` (a random value of 32 or more bytes). Add `XAI_API_KEY` **only** if you buy xAI credits yourself.
4. Read the **real** limits: the Gemini free-tier limits for the chosen model in AI Studio, and your Groq Limits page. Set `dailyBudget` in `gateway/config/routing.json` below those limits (an agent PR can do this edit from the numbers you report).
5. Run `npm run eval` locally (M3-T21) and confirm the model picks.

**HUMAN GATE HG4 — on-phone cloud check (after M3-T14 and HG3; before M3-T22).** Install a new Archive IPA, then:
- Bind the gateway URL and token in the Codex. "Test connection" passes, and the Codex shows the route and model.
- A 3-turn conversation streams and keeps context.
- Cancelling mid-answer stops the output.
- "Remember that …" appears in the Archive.
- With `GROQ_API_KEY` temporarily removed or invalid, answers still arrive (from the backup).
- In airplane mode, the offline message appears (on-device after M3.5).

**After HG4:**

| ID | Task | Likely files | Acceptance (CI-provable) | Size | Deps |
|---|---|---|---|---|---|
| M3-T22 | Retire the in-app direct providers | Services/AI/{GrokAIProvider,GeminiAIProvider,GrokAPIModels}.swift (delete), App/DependencyContainer.swift, UI/CodexView.swift, one-time Keychain cleanup of the old keys | The app holds only the gateway URL and token. `rg -i 'x-goog-api-key\|api\.x\.ai\|generativelanguage' --glob '*.swift'` is empty. xAI remains possible only as a gateway candidate, if Christopher adds credits and `XAI_API_KEY`. AppTests: the migration deletes the old keys. | S | M3-T6, **HG4** |

### M3.5 — Apple Intelligence & App Intents throughout
**Goal:** **on-device first.** Mercury uses the on-device Apple Foundation Model as its private mind: it parses intent, picks the aspect, chooses tools/actions, extracts memories, writes summaries and answers offline. Speech is transcribed on-device. Mercury also and exposes its memory, aspects and diagnostics to Siri, Spotlight, Shortcuts and Apple Intelligence. Everything goes through `IntelligenceSurface` → `MercuryBrain`. **Exit:**
- On an Apple Intelligence device, intent/aspect/action planning runs on-device. With the gateway unbound, offline, failing or out of budget, Ask answers on-device.
- Unavailability is explained, and no mock text remains.
- Memory, Aspect and Diagnostics intents/entities have fake-backed SPM tests.
- Memories appear in Spotlight (toggle).
- Snippets render in Mercury style.
- All CI jobs pass with the iOS 18 minimum.

**Build rules for this milestone (CI facts):**
- CI uses Xcode 26.3 (iOS/macOS 26 SDK), so iOS 26 APIs compile. Every use needs `#if canImport(FoundationModels)` plus `@available(iOS 26.0, macOS 26.0, *)` / `if #available`. The deployment floor stays iOS 18 and SPM macOS 15.
- SPM tests run on a macOS 15 runner, where FoundationModels is unavailable at runtime. So the model sits behind a ServicesAI-internal seam (`OnDeviceModelClient`, not a Core protocol) with a fake.
- The simulator job can run the real Tool/intent wrappers on an iOS 26 simulator, where model availability is expected to be `.unavailable`. Real generation is verified only on the phone (HG5).
- `FoundationModels` must be weak-linked for pre-26 devices.
- iOS 27-only APIs are listed under *Deferred* below.

*Rows are in execution order (IDs are stable, so they're not strictly sequential).*

| ID | Task | Likely files | Acceptance (CI-provable) | Size | Deps |
|---|---|---|---|---|---|
| M3.5-T1 | On-device model seam + availability | Services/AI/OnDevice/OnDeviceModelClient.swift (internal protocol + `SystemOnDeviceModelClient` wrapping `SystemLanguageModel.default` / `LanguageModelSession`), Services/AI/OnDevice/OnDeviceAvailability.swift, project.yml (`OTHER_LDFLAGS: -weak_framework FoundationModels` on ServicesAI and the app) | `OnDeviceAvailability` maps `.available`, `.unavailable(.deviceNotEligible / .appleIntelligenceNotEnabled / .modelNotReady / other)` and "OS < 26". SPM tests with a fake client cover each mapping. Builds for iOS 18 floor; `otool -l` on the simulator app in the CI build step shows `LC_LOAD_WEAK_DYLIB` for FoundationModels. | S | M2-T1 |
| M3.5-T2 | `FoundationModelsAIProvider: AIProvider` | Services/AI/OnDevice/FoundationModelsAIProvider.swift, Core/AppError.swift (`onDeviceUnavailable(reason)`, `contentRefused`) | Creates a fresh `LanguageModelSession(instructions:)` per request (history rendered into the prompt), except that a session prewarmed by M3.5-T4 is handed to, and consumed by, the next request and calls `respond(to:options:)` with `GenerationOptions(temperature:maximumResponseTokens:)`. Maps `GenerationError` cases `exceededContextWindowSize`, `guardrailViolation`/`refusal`, `unsupportedLanguageOrLocale`, `assetsUnavailable` and `rateLimited` to typed `AppError`s, and propagates cancellation. SPM tests via the fake client cover success, each error mapping and cancellation. `isAvailable` reflects T1. | M | M3.5-T1, M3-T5 |
| M3.5-T3 | Routing: on-device first; mock removed for users | Services/AI/AIService.swift, App/MercuryBrain.swift, UI (unbound copy) | Routing is driven by `AIRoutingConfig` (M3-T4). The **plan** (from `IntentEngine` until M3.5-T19 lands the on-device plan), memory extraction, summaries and tool calls always run on-device. The answer is on-device unless the plan says `needsCloud` **and** the gateway is bound and online; then it goes to the gateway, falling back to on-device on gateway failure or `budget_exhausted`. **Offline → on-device without touching the network.** If on-device is unavailable, a typed error carries the reason and the UI shows "Intelligence unbound — bind the gateway in the Codex or enable Apple Intelligence". `MockAIProvider`/`FakeStreamingProvider` are referenced only from tests and the `-uitest` path. **Flag semantics:** `aiServiceEnabled` is split into `onDeviceIntelligenceEnabled` (default **on**, so a fresh keyless install gets on-device answers) and `cloudIntelligenceEnabled` (default off; set on when the gateway is first bound). A one-time FeatureFlags migration maps an explicit user "off" to both off. The Codex toggles control each separately. SPM and AppTests cover each route, and separately a fresh install vs. a user-disabled service. | M | M3.5-T2, M1-T3, M3-T7, M3-T5 |
| M3.5-T4 | On-device context budget + prewarm | App/MercuryBrainComposition.swift, App/MercuryBrain.swift | When the resolved provider is on-device, the Brain builds a **compact** prompt (short instructions, at most 3 memory items, at most 4 history turns, device line). On `exceededContextWindowSize` it retries once with a minimal prompt. `prewarm(promptPrefix:)` is called on a session created when the Invocation opens (if availability is `.available`), and **that same session** serves the next request; it is discarded after use or when the Invocation closes. AppTests assert the compact prompt stays within a character budget, the retry happens once, and (via the fake client) the prewarmed session's identity equals the one used for the next request. | S | M3.5-T3, M3-T9 |
| M3.5-T5 | Codex: on-device mind status | UI/CodexView.swift, UI/CodexViewModel.swift | The "Mind" section shows the on-device state (Available / Apple Intelligence off / Preparing model / Not eligible / Requires iOS 26) and the active route (On-device / Gateway: model name from `/v1/config`). AppTests cover the status strings with a fake availability. | S | M3.5-T3, M1-T5 |
| M3.5-T6 | Guided generation: memory distillation | Services/AI/OnDevice/MemoryDistillation.swift (`@Generable struct MemoryDistillation { title; category (@Generable enum mirroring MemoryItem.Category); importance @Guide(.range(0...1)) }`), App/MercuryBrain.swift (remember path) | When on-device is available, `remember` stores the distilled title and category and blends the importance with `MemoryScorer`. Otherwise it falls back to the current behavior. The call goes through `respond(to:generating:)`, and the note text is never sent to cloud providers for this. SPM tests (fake client returns a distillation) and AppTests (unavailable → fallback). | M | M3.5-T2 |
| M3.5-T7 | Guided generation: structured diagnosis | Services/AI/OnDevice/DiagnosisReport.swift (`@Generable` summary / severity enum / up to 3 suggestions), App/MercuryBrain.swift (`diagnose()` on `IntelligenceSurface`), UI/DiagnosticsView.swift | Diagnostics shows the report. When on-device is unavailable, a deterministic report from `InsightEngine`/`NexusState` is used. SPM tests cover the fallback builder; AppTests cover the Brain path with a fake. | M | M3.5-T6 |
| M3.5-T20 | Shared action registry *(absorbs old M3-T11)* | Core/Models/MercuryAction.swift (enum: `remember`, `recallMemories`, `status`, `enterAspect`, `openDiagnostics`), Core/Protocols/IntelligenceSurface.swift (+`perform(_:)`; same protocol, not a new one), App/MercuryBrain+Capabilities.swift | Intents (T11–T17) and model tools (T8) are thin adapters over `perform(_:)`. The today-uncalled `Brain.invoke` is folded in. SPM tests with a fake surface cover each action. AppTests cover `.remember` storing the note and `.recallMemories` returning ranked items. | M | M1-T6, M3-T14 |
| M3.5-T8 | Tool calling: **App Intents actions are the model's tools** | Services/AI/OnDevice/Tools/ActionTool.swift (one `Tool` adapter per `MercuryAction` from M3.5-T20, with `@Generable Arguments`), App/MercuryBrain.swift | At most 5 tools (remember, recall memories, status/device state, enter aspect, open Diagnostics). Every tool executes through the same registry the App Intents use, never the stores directly. Write actions (remember, enter aspect) are confirmed in the reply. SPM tests: each tool name maps 1:1 to a registry action that also has an App Intent. AppTests on the iOS 26 simulator call `call(arguments:)` directly and assert the registry spy saw the action. The tools are attached only to the on-device session; the cloud gets no tools. | M | M3.5-T4, M3.5-T20, M3-T14 |
| M3.5-T19 | On-device invocation planning | Services/AI/OnDevice/InvocationPlan.swift (`@Generable struct InvocationPlan { intent: IntentKind; aspect: Aspect?; action: MercuryActionKind?; needsCloud: Bool; memoryQuery: String? }`), App/MercuryBrain.swift | When on-device is available, the plan replaces the keyword `IntentEngine` (which stays as the fallback). The plan drives the aspect switch, the registry action and the memory query. SPM tests with the fake client cover each field, and the fallback when unavailable. | M | M3.5-T6, M3.5-T20 |
| M3.5-T9 | Discoverable framework intents *(was M5-T4)* | App/QuicksilverAppIntentsPackage.swift, Intents/QuicksilverIntentsPackage.swift (`AppIntentsPackage`) | The app package includes the Intents framework package. The simulator build passes. **Device check in HG5.** | S | M1-T7 |
| M3.5-T10 | Cold-start-safe intents *(was M5-T5)* | App/QuicksilverApp.swift, Intents/IntentDependencies.swift | The surface is configured during `App.init`. An unconfigured state throws a readable dialog ("Open Mercury once"). SPM test. | S | M1-T6 |
| M3.5-T11 | `MemoryEntity` + queries | Intents/Entities/MemoryEntity.swift (`AppEntity`, `DisplayRepresentation` with title/subtitle, `EntityStringQuery` + `suggestedEntities`), Core/Protocols/IntelligenceSurface.swift (+`memories(matching:)`, `memory(id:)`, `deleteMemory(id:)`) | Only user notes and distilled memories are exposed; chat turns are never exposed. SPM tests with a fake surface cover `entities(for:)`, `entities(matching:)` and suggested entities. | S | M3.5-T10, M3-T14 |
| M3.5-T12 | Memory intents on the `.journal` assistant schemas + donations | Intents/MemoryIntents.swift: `@AssistantIntent(schema: .journal.createEntry)`, `.journal.search`, `.journal.deleteEntry` (with `requestConfirmation`); `@AssistantEntity(schema: .journal.entry)` on `MemoryEntity`; replaces `CaptureMemoryIntent`; UI remember paths donate through `IntentDonationManager` | Each intent calls only `IntelligenceSurface`. Delete asks for confirmation. SPM `perform()` tests with a fake cover create, search, delete and the confirmation path. Donations happen only for UI-originated creates (AppTests with a spy). | M | M3.5-T11 |
| M3.5-T13 | Spotlight: memories as `IndexedEntity` | Intents/Entities/MemoryEntity.swift (`IndexedEntity`), App/SpotlightIndexer.swift (EventBus `memoryDidUpdate` → `CSSearchableIndex(name:).indexAppEntities` / `deleteAppEntities(identifiedBy:ofType:)`), UI/CodexView.swift toggle "Memories in Spotlight", Core/FeatureFlags.swift | Index on create/update; delete on delete, clear and retention prune. On launch: a full reindex **only if the persisted toggle is on**; if it is off, call `deleteAppEntities(ofType:)` so the index stays empty. Turning the toggle off calls `deleteAppEntities(ofType:)` immediately. Chat turns are never indexed. AppTests use an indexer spy (index protocol local to the App target) to cover each path, including relaunch with the toggle off (no index calls, one delete). | M | M3.5-T11 |
| M3.5-T14 | Aspect & Diagnostics as App Intents entities | Intents/Entities/AspectAppEnum.swift (`AppEnum`, replaces `AspectEntity` from M1-T7), Intents/Entities/DiagnosticsEntity.swift + `ReportStatusIntent` / `EnterAspectIntent` / `CurrentAspectIntent` | Status returns `ProvidesDialog` (full and supporting strings, in Mercury's voice) built from `IntelligenceSurface.diagnose()` / `statusReport`. SPM tests with a fake cover each intent. | S | M3.5-T7, M3.5-T10 |
| M3.5-T15 | "Open Diagnostics" deep link *(was M5-T6)* | Intents/QuicksilverIntents.swift, App (pending-destination state), UI/SanctumView.swift | `OpenDiagnosticsIntent.perform()` (`openAppWhenRun`) calls a shared `PendingDestination` handler that persists the destination, and on launch or foreground the Sanctum consumes it and presents Diagnostics. An SPM test calls `perform()` with a fake store and asserts the persisted destination. The XCUITest seeds the destination **through the same shared handler** (the launch argument invokes the handler, not UI state), cold-launches, and asserts Diagnostics is visible. | S | M2-T11 |
| M3.5-T23 | Shared design-token module for the intents framework | project.yml (new `QuicksilverDesignTokens` framework: SwiftUI-only, no app/business dependencies; UI and `QuicksilverIntents` both depend on it), UI/PersonaTheme.swift + UI/MotionTokens.swift → DesignTokens/ (made `public`), call sites | The snippet views in `QuicksilverIntents` can use the same tokens without an upward or cyclic dependency or duplicated values. `rg 'Color\(red' --glob '*.swift'` matches only the token module. Structure contract list updated. Simulator build passes. | M | M1-T11 |
| M3.5-T16 | Ask Mercury intent + Mercury-styled snippets | Intents/AskMercuryIntent.swift (`ProvidesDialog & ShowsSnippetView`), Intents/Snippets/{AnswerSnippet,StatusSnippet}.swift (tokens from `QuicksilverDesignTokens`, M3.5-T23; no chat bubble) | Ask goes through `IntelligenceSurface.ask` (so it works on-device when offline or keyless); ReportStatus shows `StatusSnippet`. SPM `perform()` tests cover dialog content with a fake. Snippet views build in the simulator job. | M | M3.5-T14, M3.5-T3, M3.5-T23 |
| M3.5-T17 | Interactive status snippet (iOS 26) | Intents/Snippets/StatusSnippetIntent.swift (`SnippetIntent`, `ShowsSnippetIntent`, `Button(intent:)` for "Remember this" / "Open Diagnostics") | Behind `@available(iOS 26.0, *)`; on older OSes it degrades to the static snippet from T16. SPM/AppTests cover the snippet intent's `perform()` with a fake. | S | M3.5-T16, M3.5-T15 |
| M3.5-T18 | Shortcuts phrases + Writing Tools | Intents/QuicksilverShortcuts.swift, UI inputs (Forge capture, Eternal observe, Archive add → `.writingToolsBehavior(.complete)`; Invocation → `.limited`; key fields → `.disabled`) | At most 10 `AppShortcut`s (Ask, Remember, Search memories, Status, Enter aspect, Open Diagnostics). Every phrase contains `\(.applicationName)`. `updateAppShortcutParameters()` is called after aspect/memory changes. An SPM test asserts the count and the phrase rule. `rg -c writingToolsBehavior UI` shows each input covered. | S | M3.5-T12, M3.5-T14 |
| M3.5-T21 | On-device conversation summaries | Services/AI/OnDevice/ConversationSummary.swift (`@Generable`), App/MercuryBrain.swift, Services/AI/CloudContextPolicy.swift | Turns older than the last 4 are rolled into an on-device summary stored locally. `.standard` cloud payloads send the summary instead of older raw turns; `.minimal` sends neither. The compact on-device prompt uses it too. SPM + AppTests with the fake. | S | M3.5-T2, M3-T11 |
| M3.5-T22 | On-device voice input | Services/Speech/VoiceInput.swift (protocol local to the target + `SpeechAnalyzerTranscriber` for iOS 26: `SpeechAnalyzer` + `SpeechTranscriber`, assets via `AssetInventory`, `DictationTranscriber` when `SpeechTranscriber.isAvailable` is false; `LegacyTranscriber` for iOS 18–25: `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`, which fails clearly and never falls back to the server), AVAudioEngine capture + format conversion (not `CaptureInputSequenceProvider`, which is iOS 27), project.yml (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`), mic control on the Ask/Invocation input | Volatile text shows dimmed and final text commits into the input. Permission-denied, locale-unsupported and assets-downloading states show clearly. Audio never leaves the device. AppTests with a fake transcriber cover the state machine. The simulator build passes with the iOS 18 floor. **Device check in HG5.** | M | M3.5-T1 |

**HUMAN GATE HG5 (after M3.5):** run on the iPhone 16e, with Apple Intelligence enabled and the English language/region.
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
- **Planning & tools:** "Enter the Forge" typed in the Invocation switches the aspect through the on-device plan. "What did I note about X?" recalls via the tool. Cloud escalation only happens for open-ended questions (the source glyph shows it).
- **Voice:** in airplane mode, dictating into the Invocation transcribes on-device.
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
| M4-T2 | SwiftData `VersionedSchema` v1 + `SchemaMigrationPlan` | Memory/SwiftDataMemoryStore.swift, Memory/MemorySchema.swift | Container built with the migration plan. SPM tests: (a) a **legacy-format fixture** created with the current unversioned `MemoryEntry` model is reopened through the migration plan and every record (content, category, importance, metadata, dates) survives; (b) a fresh v1 store opens. | S | M4-T1 |
| M4-T3 | Batch clear | Memory/MemoryManager.swift | `clearAll` uses `deleteAll(in:)` per category and publishes one update. Partial-failure semantics are kept (the existing CHR-30 test passes). | S | M2-T8 |
| M4-T4 | Retention and pruning on launch **and on write** | Memory/MemoryManager.swift (`applyRetention(now:)`), App/DependencyContainer.swift | First, a one-time migration reclassifies explicit user notes (today stored as `.temporary` by `MercuryBrain.remember`) as durable, tagged `source: user`, and `remember` stops writing `.temporary`. Retention then prunes **only** conversation turns and system-generated temporary items (never `source: user`) whose decayed importance is below a floor, and caps the total (constants in one place). Runs on launch and after any write that takes the count over the cap, so a long-running process stays bounded. SPM tests use a fixed `now`, including many writes in one session never exceeding the cap, and user notes surviving any amount of decay. | M | M4-T3, M4-T2 |
| M4-T5 | Surface memory load failures | Memory/MemoryManager.swift (`loadError`), UI/MemoryView.swift | A failed load shows an error row, not an empty list. SPM + AppTests. | S | M2-T6 |
| M4-T6 | Atomic Keychain writes | Core/KeychainStore.swift | `SecItemUpdate`, falling back to `SecItemAdd`, returning a status. AppTests (simulator Keychain) cover set/overwrite/delete. | S | M2-T1 |
| M4-T7 | Accurate Privacy Manifest | PrivacyInfo.xcprivacy, ci.yml Structure (validate plist with `python3 -c plistlib`) | Declares crash data and performance data (not linked, not tracking). Declares **other user content** (the trimmed question/context sent through the gateway to AI providers) as **linked to the user**, for App Functionality and not tracking, because the providers receive it under the owner's provider accounts/keys. Audio is **not** collected (speech is on-device). The plist parses in CI. | S | — |
| M4-T8 | Sentry: errors + hangs only, centralized and scrubbed | App/QuicksilverApp.swift → App/CrashReporting.swift, project.yml (Info.plist key for the DSN) | **Remove performance tracing and profiling**: no `tracesSampleRate`, no `configureProfiling`. `enableMetrics = false` and `enableCaptureFailedRequests = false`. Crash reporting and `enableAppHangTracking` stay on. DSN comes from Info.plist; release/dist come from the bundle version; `beforeSend`/`beforeBreadcrumb` redact via `LoggerService.redact` and strip URL queries; `sendDefaultPii = false`; disabled under XCTest/`-uitest`. AppTests assert the options object (traces/profiling/metrics off, hangs on) and the scrubber. | M | M2-T1, M1-T13 |
| M4-T9 | Crash-reporting opt-out in the Codex | UI/CodexView.swift, Core/FeatureFlags.swift (`crashReporting`), App/CrashReporting.swift | The toggle persists and takes effect **immediately**: turning it off calls `SentrySDK.close()` in the running process, and Sentry does not start on later launches while it is off. Turning it back on starts Sentry without a relaunch. AppTests cover all three through a crash-reporting wrapper spy. | S | M4-T8 |
| M4-T10 | Version from the bundle | Core/AppConfiguration.swift | `version`/`build` read from `CFBundleShortVersionString`/`CFBundleVersion`, with the fallback kept for SPM. The Codex "Record" shows the real build. | S | — |
| M4-T11 | Remove memory content from logs | Intents/QuicksilverIntents.swift (`"Memory capture persisted: \(truncated.prefix(60))"`), audit `logger.*` calls | No log line interpolates memory or prompt content (test with `rg` in CI, or code review). | S | M1-T6 |
| M4-T12 | Diagnostic test-event action *(was M6-T3)* | UI/CodexView.swift ("Record" section), App/CrashReporting.swift | A "Send diagnostic event" button (and a test crash behind a confirm, Release included) exists for HG6. AppTests cover the action with a stub. | S | M4-T8 |

**HUMAN GATE HG6 (after M4-T9 and M4-T12):** confirm the repo secret `SENTRY_AUTH_TOKEN` is set (org `inbetween`, project `quicksilver`). Run the Archive, trigger a test crash (see M4-T12) and confirm a **symbolicated** event arrives. Then turn the opt-out on and confirm no events arrive.

### M5 — Experience completion (Nexus, VisualState, Intents, performance, accessibility)
**Goal:** every shipped surface is complete, responsive, efficient and accessible, and Ask becomes an Invocation. **Exit:** VisualState shows live; animations are cadence-governed; Ask has no bubble-chat UI; the accessibility audit passes in CI. *(Former M5-T4/T5/T6, the intents work, moved to M3.5 as M3.5-T9, T10 and T15. IDs M5-T4..T6 are retired.)*

| ID | Task | Likely files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M5-T1 | Publish insights on the EventBus | Core/EventBus.swift (`insightGenerated`), Nexus/NexusCoordinator.swift, UI/DiagnosticsViewModel.swift | Remove the Diagnostics 60 s fallback timer. SPM test: an insight → an event. | S | M0-T2 |
| M5-T2 | Health score includes thermal and storage | Nexus/NexusCoordinator.swift | Weighted score. SPM tests: serious thermal or storage under 5% lowers the score. | S | — |
| M5-T3 | Live VisualState propagation | UI/*ViewModel.swift, UI/SanctumView.swift | Views read `container.brain.visualState` through Observation, not snapshot copies. AppTests: during `ask`, the Sanctum-facing state is `.thinking`. | S | M2-T5 |
| M5-T7 | Animation cadence policy | UI/MotionTokens.swift (`AnimationCadence`), UI/{QuicksilverCoreView,MercuryVisualSystem,AmbientLayer,ForgeView,ObservatoryVisuals}.swift | Every `TimelineView` takes the policy: paused when scenePhase is not active, when covered by a realm, or under Reduce Motion; 15 fps in Low Power Mode. AppTests unit-test the policy. `rg 'paused: false' UI` is empty. | M | M2-T1 |
| M5-T8 | Tokenize literals in ForgeView and QuicksilverCoreView | UI/ForgeView.swift, UI/QuicksilverCoreView.swift, PersonaTheme/MotionTokens | **No** numeric literals for opacity, padding/spacing, frame, corner radius, blur, line width or duration remain; every visual and motion value comes from `PersonaTheme`/`MotionTokens` (AGENTS.md; they live in `DesignTokens/` once M3.5-T23 lands). Only structural `0`/`1` (e.g. `.opacity(0)` for hidden, `scaleEffect(1)`) are allowed. A CI-runnable `rg` check over these modifiers in the touched files returns nothing, and `rg 'Color\(red' --glob '*.swift'` matches only the token source (`UI/PersonaTheme.swift`, or `DesignTokens/` after M3.5-T23). Build + UI smoke pass. | M | M1-T11 |
| M5-T9 | Tokenize literals in Eternal, Observatory, Sanctum and RuneGlyph | UI/{EternalView,ObservatoryPanels,ObservatoryVisuals,SpatialSanctum,RuneGlyph}.swift | Same criterion. | M | M1-T11 |
| M5-T10 | Accessibility pass A: Sanctum, Forge, Eternal | the related UI files | Labels/hints on glyphs and gateways; decorative layers `accessibilityHidden`; fixed `.system(size:)` fonts replaced with Dynamic Type styles. XCUITest `performAccessibilityAudit()` on these screens passes. | M | M2-T11 |
| M5-T12 | Ask → "Invocation" surface: layout | UI/AskView.swift → UI/InvocationView.swift, UI/AskViewModel.swift, PersonaTheme/MotionTokens | No bubbles, no chat list and no "Provider:" chrome. The Quicksilver core is the focal point: the current utterance and response render as an inscription around the presence, and earlier exchanges are reachable as "Echoes" (opening the Archive filtered to conversation). The input uses Writing Tools `.limited`. Tokens only (no literals). AppTests: VM keeps the full history while the view shows only the current exchange. UI smoke test updated. | M | M2-T11, M3-T10 |
| M5-T13 | Invocation: presence states, motion, accessibility | UI/InvocationView.swift, UI/QuicksilverPresenceView.swift | The core's VisualState drives listening/thinking/speaking; streaming or progressive reveal of the response honors Reduce Motion; the on-device vs. cloud source is shown as a subtle glyph, not a label. VoiceOver reads each exchange as one element. `performAccessibilityAudit()` passes on the Invocation surface. | M | M5-T12, M5-T3 |
| M5-T11 | Accessibility pass B: Invocation, Archive, Codex, Diagnostics | the related UI files | Same audit passes for these destinations and runs in CI. | M | M5-T10, M5-T13 |

**HUMAN GATE HG7 (after M5-T11):** judge the Invocation redesign on the phone ("a place, not a chat"). Then run VoiceOver across all destinations, with the largest Dynamic Type and Reduce Motion on. Then do a battery/thermal soak: 20 min in the Sanctum in the foreground plus 1 h in the background, and compare Settings → Battery. Report anything abnormal.

### M6 — Release readiness (v1.0.0)
**Goal:** a trustworthy release pipeline and documentation for 1.0.0. **Exit:** the Archive job fails hard on missing essentials; CHANGELOG and release checklist exist; version is 1.0.0; all human gates are signed off.

| ID | Task | Likely files | Acceptance | Size | Deps |
|---|---|---|---|---|---|
| M6-T1 | Harden the Archive checks | .github/workflows/archive.yml | Missing persona prompts or PrivacyInfo becomes an **error**. Verify `Sentry.framework` is embedded, and that Info.plist version/build match `project.yml`. **Tagged release parity:** `release.yml` rebuilds its own IPA, so either publish the verified Archive artifact or mirror the same checks plus the dSYM upload in `release.yml`'s build job, leaving its dormant TestFlight step untouched. This edits a release workflow, so it **needs Christopher's explicit OK** in the PR. (Workflow change only; the owner runs it in HG8, and HG9 verifies the tagged artifact.) | M | M4-T10 |
| M6-T2 | Document dormant release paths | README.md, Documentation/SIDESTORE.md (docs only; **do not modify** codemagic.yaml, fastlane/ or release.yml) | README states that Codemagic, Fastlane and the TestFlight step are dormant and that SideStore is the only supported path. Structure job passes. | S | M1-T12 |
| M6-T4 | CHANGELOG | CHANGELOG.md | Entries from 0.2.0 (build 7) to now, generated from merged PRs. | S | — |
| M6-T5 | Owner release checklist | Documentation/RELEASE.md, README link | Lists HG1–HG9 with steps and pass criteria. | S | M1-T12 |
| M6-T6 | Bump to 1.0.0 | project.yml (`MARKETING_VERSION 1.0.0`, `CURRENT_PROJECT_VERSION`+1), docs | Archive banner shows 1.0.0. All 4 CI jobs are green. | S | all above |

**HUMAN GATE HG8:** run *Archive IPA* (Release) for 1.0.0 and install it over the previous build. Confirm memory and keys persist. Wait through or force a SideStore 7-day refresh and confirm data persists. Run the full first-run checklist.
**HUMAN GATE HG9:** final sign-off. Tag `v1.0.0` (this triggers `release.yml`). Merge decisions stay with the owner (AGENTS.md autonomy policy).

---

## 5. Risks

1. **iOS 27 SDK gap.** CI's Xcode 26.3 has no iOS 27 SDK, so the newest Apple Intelligence APIs can't be adopted or CI-verified yet (see M3.5 *Deferred*).
2. **On-device model isn't testable in CI.** Model generation quality and availability are verified only on the phone (HG5). CI verifies mapping, routing, prompts and tools with fakes.
3. **Weak linking.** A missing `-weak_framework FoundationModels` would crash pre-iOS-26 launches. M3.5-T1 checks the load command.
4. **Siri/Apple Intelligence rollout.** Assistant-schema behavior in Siri depends on OS rollout, language and region. Shortcuts/Spotlight/snippets work regardless.
5. **Model IDs.** Until M3-T22, `gemini-3.7-flash` (listed on Google's rate-limit page) and `grok-4.6` are hard-coded; HG1 proves Gemini. After M3, IDs live only in the gateway's routing config and can change without an app rebuild.
6. **App Intents in a framework.** Shortcuts discovery depends on `AppIntentsPackage` wiring (M3.5-T9). CI can only prove that it compiles; HG5 proves discovery.
7. **Xcode 26.3 on CI, iOS 27 on device.** Builds run in compatibility mode on iOS 27, and iOS 27 SDK behavior is untested until runners ship Xcode 27. The docs' "iOS 18 SDK" claim is already wrong (M1-T12).
8. **CI time and flakiness.** Adding app-hosted tests and XCUITest to the Simulator job (M2-T1, M2-T11) adds minutes and simulator flakiness. Keep UI tests to smoke + audit only.
9. **SwiftData schema change without a migration plan** could wipe or crash memory. Land M4-T2 before any `MemoryEntry` change.
10. **Free tiers change without notice.** Limits, model lists and terms are provider-controlled (e.g. Groq moved some models to Enterprise-only in Aug 2026, as reported by a third-party pricing guide). Mitigations: config-driven model swaps on the gateway, per-candidate daily budgets, and on-device fallback, so a vanished free tier degrades Mercury rather than breaking it.
11. **Gemini free tier trains on prompts and has consumer-use wording.** Unpaid Gemini API use lets Google use prompts/responses to improve products, with human review. The terms say not to submit sensitive or personal data and describe the API as for developers building for professional or business purposes, "not for consumer use". It is therefore only the **backup**, and always gets `.minimal` context (M3-T11). See Q8.
12. **Workers Free CPU budget.** 10 ms CPU per request (time spent waiting on `fetch` doesn't count). The stream adapters must be light (line-level passthrough, no heavy JSON re-serialisation). Measure in HG4; if it's exceeded, the request fails with a Workers error and the app falls back on-device.
13. **Best-effort rate limiting.** Without a verified free Rate Limiting binding, in-isolate counters aren't global. Provider-side limits (429) remain the backstop, and the device token keeps the gateway private.
14. **Different daily reset clocks.** Workers Free and Workers AI reset at 00:00 UTC; Gemini RPD resets at midnight Pacific. Budgets are enforced per provider.
15. **Unverifiable limits.** Gemini free per-model limits are only visible in AI Studio. Groq's public table is labelled as Developer-plan base limits, so the exact Free numbers are only visible on the account's Limits page. OpenRouter's free-model caps didn't render publicly. HG3 records the real numbers into the gateway config.
16. **Concurrent workers.** M0/M1 touch the same files as the other worker (VMs, Brain). Run the backlog strictly in order.

## 6. Open product questions (owner only)

All six earlier questions are answered (see *Owner decisions* at the top). One small question remains:
- **Q7 — Spotlight default:** should memories be indexed in Spotlight **on by default** (user notes only, never chat), with the Codex toggle to turn it off? M3.5-T13 assumes on by default unless you say otherwise.
- **Q8 — Gemini as backup:** Gemini's free-tier terms say the API is for developers building for professional or business purposes, not for consumer use, and unpaid prompts may be read by human reviewers. Mercury is your personal app and gets only `.minimal` context, but if you'd rather not rely on that, the router can drop Gemini and use Workers AI as the backup (it doesn't train on your data; its free allocation is smaller). The default plan keeps Gemini as the second candidate.

## 7. Task count

| Milestone | Tasks |
|---|---|
| M0 In flight | 2 (1 done) |
| M1 Ship-blocker + legacy cleanup | 13 (M1-T13 moved from old M3-T1) |
| M2 Test & CI foundation | 11 |
| M3 Mercury Gateway & free cloud intelligence | 22 (15 app: T1–T14 + T22; 7 gateway: T15–T21; reworked from 11) |
| M3.5 Apple Intelligence & App Intents | 23 (3 moved from M5; 5 added: on-device planning, action registry, summaries, voice, shared design tokens) |
| M4 Memory, data & privacy | 12 (M4-T12 moved from M6-T3) |
| M5 Experience completion | 10 (3 moved out, 2 Ask tasks added) |
| M6 Release readiness | 5 (M6-T3 moved to M4-T12) |
| **Total** | **98** (97 open) + 9 human gates (HG1–HG9) and the #135 merge |

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
| On-device speech | `SpeechAnalyzer` + `SpeechTranscriber` / `DictationTranscriber`, `AssetInventory` (iOS 26); `SFSpeechRecognizer` with `requiresOnDeviceRecognition` for iOS 18–25 | https://developer.apple.com/documentation/speech/speechanalyzer · https://developer.apple.com/documentation/speech/speechtranscriber · WWDC25 "Bring advanced speech-to-text to your app with SpeechAnalyzer" https://developer.apple.com/videos/play/wwdc2025/277/ · https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition |
| On-device embeddings | `NLContextualEmbedding` (iOS 17), `NLEmbedding.sentenceEmbedding(for:)` (iOS 14) | https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding · https://developer.apple.com/documentation/naturallanguage/nlembedding |
| Deferred (iOS 27 SDK) | Foundation Models 2026 (`LanguageModel` protocol, PCC, Dynamic Profiles, OCR/Spotlight tools); App Intents 2026 (`IndexedEntityQuery`, `SyncableEntity`, `RelevantEntities`, on-screen awareness); `AppIntentsTesting` | https://developer.apple.com/videos/play/wwdc2026/241/ · https://developer.apple.com/videos/play/wwdc2026/345/ · https://developer.apple.com/videos/play/wwdc2026/343/ · https://developer.apple.com/documentation/appintentstesting |

Note: `CaptureInputSequenceProvider` (the Speech framework's mic-input helper) is iOS 27-only, so M3.5-T22 uses AVAudioEngine capture until CI has Xcode 27.

## 9. Free AI stack: gateway and models (researched 2026-09-25)

Rule: **free only, no paid services.** Numbers are copied from the official pages on the date above. Where a number couldn't be verified publicly, the table says so. HG3 records the real numbers from the owner's own consoles into `gateway/config/routing.json`.

### Gateway: **Cloudflare Workers Free** (picked) vs Vercel Hobby

| | Cloudflare Workers Free | Vercel Hobby |
|---|---|---|
| Requests | 100,000/day, reset 00:00 UTC (error 1027 when exceeded) | 1,000,000 function invocations included; exceeding usage usually means waiting 30 days |
| Compute | 10 ms CPU per request; waiting on `fetch` doesn't count; no wall-time limit on HTTP while the client stays connected (streaming OK) | 4 active CPU-hours; functions max 300 s duration |
| Other | 50 subrequests/request, 128 MB memory, 64 secrets/env vars, 100 Workers | 200 projects, 100 deployments/day, 1 h runtime logs |
| Terms catch | No personal-use-only clause on the plan/limits pages (read the Self-Serve Subscription Agreement at HG2) | **"Non-commercial, personal use only"** (fair-use guidelines) |
| Bonus | Built-in **Workers AI** (10,000 Neurons/day free) as a no-extra-key fallback model | — |

**Pick:** Cloudflare Workers Free. It streams without a duration cap, has daily rather than 30-day lockouts, has no non-commercial restriction, and includes a free fallback model. Sources: https://developers.cloudflare.com/workers/platform/limits/ · https://developers.cloudflare.com/workers/platform/pricing/ · https://vercel.com/docs/plans/hobby · https://vercel.com/docs/limits/fair-use-guidelines

### Cloud models (only genuine free API tiers)

| Candidate | Free tier (verified?) | Trains on free prompts? | Role |
|---|---|---|---|
| **Groq — `openai/gpt-oss-120b`** (alt `openai/gpt-oss-20b`) | Free plan: $0, no payment method (groq.com/groqcloud). The public table shows 30 RPM / 1K RPD / 8K TPM / 200K TPD for these models, **but it is labelled "base limits for the Developer plan"**, so the exact Free numbers are **unverified**; read them on the console Limits page (HG3). 429 with `retry-after`. | **No.** "Groq is not permitted to use Inputs or Outputs for training" without permission; no inference retention by default (up to 30 days only for reliability/abuse); Zero Data Retention toggle available to all customers. | **Primary** (`.standard` context) |
| **Google Gemini API — Flash family** (e.g. `gemini-3.7-flash`; final pick by eval) | Free tier exists for unpaid projects. Per-model RPM/TPM/RPD are **not published; only visible in AI Studio** (unverified). Limits are per project; RPD resets at midnight Pacific. | **Yes.** Unpaid: content is used to improve Google products and **human reviewers may read it**. "Do not submit sensitive, confidential, or personal information." Also: 18+, "not for consumer use" wording, and EEA/UK/CH must use Paid Services. | **Backup** (always `.minimal` context) |
| **Cloudflare Workers AI** (e.g. `@cf/meta/llama-3.1-8b-instruct-fp8-fast`) | 10,000 Neurons/day on Workers Free, reset 00:00 UTC; more requires Workers Paid (not allowed). That model costs 4,119 neurons per M input and 34,868 per M output tokens. *Estimate, not a published limit:* a 1,000-in / 300-out request ≈ 14.6 neurons, so roughly 680 such requests/day. Some catalog models require a paid billing method. | **No.** Cloudflare doesn't use Customer Content to train models or improve services without explicit consent. | **Last-resort fallback** inside the gateway (no extra key) |
| OpenRouter `:free` models | Free variants exist, but the RPM/RPD numbers depend on credits purchased and **didn't render publicly** (unverified); a negative balance can block free models; the upstream host varies per model. | Varies per upstream (not verified) | Not picked |
| Mistral free (Experiment/Free) | Exists; limits not verified. | **Yes by default** on the free Studio/API mode (opt-out toggle in the Admin panel) | Not picked |
| xAI Grok | No free API tier located | — | **Optional**: add `XAI_API_KEY` only with your own credits; the router then lists it as an extra candidate |

**Picks:** primary **Groq gpt-oss-120b**, because it doesn't train on prompts, is fast, is OpenAI-compatible and has published per-model caps. Backup **Gemini Flash** with minimal context. Last resort **Workers AI** inside the gateway. On-device Apple Foundation Models always comes before and after all of these.

Sources:
- Groq: https://console.groq.com/docs/rate-limits · https://groq.com/groqcloud · https://console.groq.com/docs/your-data · https://console.groq.com/docs/legal/services-agreement
- Gemini: https://ai.google.dev/gemini-api/docs/rate-limits · https://ai.google.dev/gemini-api/terms
- Cloudflare: https://developers.cloudflare.com/workers-ai/platform/pricing/ · https://developers.cloudflare.com/workers-ai/platform/data-usage/
- OpenRouter: https://openrouter.ai/docs/api/reference/limits
- Mistral: https://help.mistral.ai/en/articles/455207-can-i-opt-out-of-my-input-or-output-data-being-used-for-training
