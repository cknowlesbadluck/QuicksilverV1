# Quicksilver (Mercury) — Production Roadmap

**Canonical repository:** `cknowlesbadluck/QuicksilverV1`  
**Primary device:** iPhone 16e / iOS 27  
**Build floor:** iOS 18.0  
**Distribution:** unsigned SideStore IPA  
**Operating constraints:** free-tier resources; on-device-first; no mandatory paid API or hosted service.

This is the living execution plan for Quicksilver 1.0. Update it in the same pull request as any change that materially changes status or acceptance criteria. Status is evidence-based: source presence is not runtime proof, simulator proof is not physical-device proof, and generated IPA is not installation acceptance.

## Product invariants

1. Quicksilver is one persistent intelligence/entity.
2. Quicksilver, Forge, and Eternal are context-determined aspects of that entity—not separate assistants, selectable personas, or independent memory stores.
3. The user never receives a manual aspect picker. MercuryBrain owns aspect decisions and VisualState.
4. Sense → Think → Express remains the governing flow: Nexus senses; MercuryBrain coordinates intent, memory, aspects and AI; UI expresses state.
5. UI and App Intents do not choose providers, prompts, memory strategies, or tool authorization.
6. Native Swift/SwiftUI and public Apple APIs only. SideStore remains the supported distribution route.
7. On-device capability is preferred. Cloud intelligence is optional, privacy-gated, and replaceable through provider abstractions.
8. No mandatory paid services, crash-reporting SDK, or external telemetry. Secrets remain in Keychain / approved secret stores and never in source control.
9. Resonance and Conduit remain separate projects. They may be optional integrations, never runtime prerequisites.

## Verified baseline — 2026-11-13

Main commit: `0adba9d2aa8ac546900fff07ebfa2bcc0d15ae1d`.

**Quicksilver CI run 43507103982 / workflow run #1834:** all six jobs completed successfully:
- Structure & Contracts
- SwiftLint
- SPM Unit Tests
- SPM Thread Sanitizer
- iOS Simulator Build (including app-hosted tests and app-icon verification)
- iOS UI Smoke and accessibility tests

**Completed repository work:**
- Native modular Swift/SwiftUI architecture, DependencyContainer composition root, and MercuryBrain coordination surface are present.
- Aspect dwell/hysteresis and continuity behavior have unit coverage.
- Memory persistence, deterministic on-device note recall, memory query models, and embedding/index foundations are present.
- Living Sanctum / Quicksilver core, Workshop, Planetarium/Observatory, Archive, Codex, PersonaTheme and MotionTokens foundations are present.
- SideStore unsigned IPA workflow and app-icon packaging guards are present.
- PR #284 removed the last production `@unchecked Sendable` conformance. Issue #252 is closed; `Tests/UncheckedSendableRatchetTests.swift` has an empty allowlist.
- PR #418 merged the current-main Dynamic Type/accessibility follow-up. Superseded PR #373 is closed.

**Open repository work:**
- PR #422: opt-in Spotlight indexing for saved notes, rebased onto current main. Preserves the current Sanctum Dynamic Type spacing and explicit Ask close control; fresh CI is running.
- PR #419: release workflow action references SHA-pinned and merged at `6db7810`; all six CI jobs passed. Issue #250 is closed.
- PR #421: this roadmap reconciliation.

**Release gate:** CHR-55 remains `deviceAcceptance: not_recorded`. Only a real install and soak on the owner's iPhone 16e / iOS 27 can close it. CI, simulator runs, static inspection, and IPA packaging cannot substitute.

---

## Milestone 1 — Audit, stabilize, consolidate

**Status: baseline largely verified; remaining work is review/merge and targeted static cleanup.**

- [x] Verify canonical repository, default branch, architecture rules and device/build targets.
- [x] Verify latest main CI at the job level; all six jobs green on 2026-11-13.
- [x] Verify strict concurrency ratchet has an empty `@unchecked Sendable` allowlist.
- [x] Verify PR #284 merged and close issue #252 as completed.
- [x] Identify and correct stale roadmap status, PR references and historical CI claims (this update).
- [x] Merge and verify PR #419; issue #250 closed after the merge.
- [ ] Review and merge PR #422 only after its complete CI and review evidence are green.
- [ ] Complete a source-wide dead-code / duplicate-path audit with local checkout, Swift tooling and tests. Do not delete code based only on search-result snippets.
- [ ] Confirm all architecture guard tests cover the invariants listed above and fail on violations.

**Exit criteria:** one coherent mainline; no known stale release blockers; all main CI jobs green; no duplicate intelligence ownership or user-facing aspect selector; all changes reviewed and traceable.

## Milestone 2 — Complete the intelligence engine

**Status: architecture and deterministic planner are implemented on main; integrated privacy validation remains open.**

- [x] MercuryBrain is the central intelligence surface and owns VisualState.
- [x] Provider abstraction and IntelligenceBroker exist.
- [x] Context-based aspect policy, dwell/hysteresis, and persistence exist.
- [x] Deterministic note recall can answer high-confidence saved-note questions locally without a model call.
- [x] M3.5-T19 local deterministic `needsCloud` planner is implemented in `Services/AI/CloudContextPolicy+Planner.swift`; `CloudPlannerTests.swift` covers core eligible/local cases, determinism and fallback gating. This is implementation-complete, not a claim that the privacy classifier is exhaustive.
- [ ] Expand and validate the cloud-planner privacy corpus across multilingual, ambiguous, indirect, quoted, code, structured-identifier and mixed-history inputs; preserve fail-closed behavior when uncertain.
- [ ] Exercise multi-turn conversation history, query-aware retrieval, ranking, retention, deletion, and relaunch persistence as integrated user flows.
- [ ] Validate provider selection, unavailable-provider handling, cancellation, timeout, rate limits, and fallback without leaking secrets or private memory.
- [ ] Validate offline/keyless behavior and confirm local failure never silently routes private context to cloud.
- [ ] Verify aspect selection on mixed-intent, ambiguous, long-running and interrupted tasks; confirm stable continuity without aspect ping-pong.
- [ ] Verify that model output cannot grant itself capabilities or bypass deterministic authorization.
- [ ] Define measurable latency, token/context budget, and memory retrieval quality targets.

**Exit criteria:** repeatable tests demonstrate correct conversation continuity, memory recall, privacy-aware routing, provider failure behavior, and autonomous aspect expression.

## Milestone 3 — Refine the living experience

**Status: visual system and spatial navigation foundations exist; final quality/performance review remains.**

- [x] Sanctum is the primary environment rather than a conventional dashboard.
- [x] Living Quicksilver mercury-core and ambient visual layers exist.
- [x] Workshop, Planetarium, Archive, Codex and Diagnostics destinations exist.
- [x] PersonaTheme and MotionTokens centralize visual and motion decisions.
- [x] Reduce Motion / UI-test motion-freeze paths exist.
- [ ] Review the complete interaction flow on the target device; identify remaining generic dashboard/chat patterns and remove only with regression coverage.
- [ ] Validate that navigation to a realm does not expose a manual aspect selector or create a separate assistant identity.
- [ ] Profile animation frame time, memory, battery and thermal behavior during sustained use; verify energy-aware throttling under Low Power and thermal pressure.
- [ ] Validate VoiceOver focus order, labels, contrast, Dynamic Type, touch targets and Reduce Motion across every destination.
- [ ] Ensure the visual state is a faithful, observable projection of MercuryBrain state and never a second source of truth.
- [ ] Review loading, empty, error, offline, permission-denied and interrupted states in each realm.

**Exit criteria:** the experience feels like one inhabited place; visual state remains coherent with intelligence state; accessibility and performance are verified on simulator and target device.

## Milestone 4 — Complete native iOS capabilities

**Status: App Intents, Shortcuts and device-signal foundations exist; end-to-end acceptance remains.**

- [x] Native App Intents package and app intent entry points exist.
- [x] Nexus exposes privacy-conscious device/environment signals.
- [ ] Saved-note Spotlight implementation is proposed in PR #422, opt-in and off by default; merge after fresh CI and final review.
- [ ] Verify cold-start App Intents and Shortcuts execution, input validation, cancellation, and user-visible errors.
- [ ] Verify Spotlight opt-in, indexing limits, deletion, retries, cross-aspect Archive routing and actual device search results before enabling by default.
- [ ] Verify Apple Intelligence / Foundation Models availability detection, unsupported-device behavior, offline behavior, and graceful fallback on the target OS.
- [ ] Complete voice interaction only where supported by public Apple APIs and explicit permissions; do not request microphone access preemptively.
- [ ] Add capability registry tests proving each advertised action is actually available and authorized.
- [ ] Confirm external integrations remain optional and that Quicksilver retains useful core functionality when every remote service is unavailable.

**Exit criteria:** native integrations work from cold start on the physical device, capability availability is truthful, and all side effects are permission- and confirmation-gated.

## Milestone 5 — Security, reliability, release hardening

**Status: strong automated baseline; release workflow pinning and physical-device acceptance remain.**

- [x] Strict Swift concurrency checking and Thread Sanitizer CI.
- [x] Empty `@unchecked Sendable` ratchet allowlist.
- [x] Private-by-default logging and secret-redaction conventions.
- [x] Keychain-backed provider credential storage and privacy boundary foundations.
- [x] Privacy manifest and source-surface guard tests exist.
- [x] SideStore unsigned IPA packaging workflow verifies app bundle and icon assets.
- [x] PR #419 merged; all four release-workflow action references are pinned to verified immutable commit SHAs. Continue auditing any newly added workflow actions.
- [ ] Audit Keychain access groups, accessibility class, deletion, rotation, and locked-device behavior.
- [ ] Audit all network, file, defaults, clipboard, location, contacts, calendar, photos, camera, microphone and health surfaces; require explicit privacy review before adding sensitive access.
- [ ] Test airplane mode, invalid credentials, exhausted quotas, provider timeouts, malformed responses, storage pressure, app termination and interrupted writes.
- [ ] Confirm no secrets, tokens, prompts, memory contents or sensitive device context appear in logs, crash output or artifacts.
- [ ] Run a release-commit Archive IPA workflow and retain the artifact with its commit SHA.
- [ ] Complete CHR-55 owner device acceptance and record results, including a 5–10 minute background/thermal observation and a 7-day SideStore refresh cycle.

**Exit criteria:** all automated security/reliability checks green; immutable workflow dependencies; successful SideStore install and soak; no unresolved critical/high findings; privacy and permission behavior accepted.

---

## Release definition — Quicksilver 1.0

Quicksilver 1.0 is not complete until all five milestones have evidence and the owner device gate is closed.

- [ ] One persistent entity with three automatic aspects; no manual aspect picker.
- [ ] Reliable MercuryBrain, provider abstraction, privacy-aware routing and truthful capability registry.
- [ ] Persistent, searchable, user-controlled memory with tested deletion and recovery.
- [ ] Cohesive Sanctum / Workshop / Planetarium / Archive / Codex experience.
- [ ] Accessible, performant living mercury presence with Reduce Motion and thermal safeguards.
- [ ] Native App Intents / Shortcuts and any shipped Spotlight/voice capabilities accepted on device.
- [ ] No mandatory paid services; useful offline/keyless core behavior.
- [ ] Security, privacy, concurrency, CI and release workflow checks pass.
- [ ] Unsigned SideStore IPA installed and exercised on iPhone 16e / iOS 27.
- [ ] CHR-55 evidence recorded and a known-good release commit/IPA SHA documented.

## Human-only acceptance gates

An agent may prepare artifacts, checklists and diagnostics, but must not claim these as complete:
- Physical iPhone 16e installation, permissions, interaction, battery/thermal soak and relaunch validation.
- SideStore refresh-cycle acceptance.
- Final owner sign-off for voice/visual quality and production release.

## Operating discipline

- One focused vertical slice per PR; no broad rewrites without a reviewed plan.
- Tests precede behavioral changes; run focused tests and full CI.
- Do not merge from an agent other than the repository-designated Quicksilver Dev. Agents may prepare reviewable PRs.
- Stop on CI failure, architecture invariant violation, security regression, or scope drift; diagnose rather than bypass.
- Keep Quicksilver independent of Resonance and Conduit.
