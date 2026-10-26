# QuicksilverV1 roadmap to 1.0

QuicksilverV1 only. Each phase has a goal, implementations and exit criteria. A phase is done when its exit criteria hold on `main` with Quicksilver CI green on all 6 jobs. Device evidence counts only if the owner records it. Agents never record or claim it.

**State as of 2026-10-26, 6:30 AM ET:** `main` is still at `a344a8d` and green. Consolidation pass, no merges: test guards #394, #399, #404 and #405 are folded into #409; memory PRs #382, #388 and #407 into #410; #398's AGENTS.md focus line into this PR. Folded PRs are closed with their branches kept. Merged overnight: #397 (only MercuryBrain sets VisualState), #400 (network I/O stays in reviewed clients), #401 (UserDefaults stays in reviewed stores), each green on main CI. Current focus: entropy reduction and CHR-55 device evidence, the sole critical path. CHR-55 is `not_recorded`.

Phase status (2026-10-26, 6:30 AM ET):
- Phase 1 (CHR-55): open; #392 gives the content-free stamp. No device evidence yet.
- Phase 2 (memory): #410 (budget, load at cap, damaged-row tolerance) open.
- Phase 3 (privacy): #409 guards open; #342 and #374 owner-held.
- Phase 6 (App Intents): #377 open; #408 bounds intent input.
- Phase 7 (accessibility): #403 and #373 open.
- Phase 8 (reliability): UI Smoke Sanctum audit still flakes until #403 lands.
- Phases 4, 5, 9, 10: no change.

Next slices, in order:
1. Merge the green guard and test PRs (see the merge order in the latest audit).
2. Merge #373 to calm UI Smoke.
3. Bound `IntegrationEventStore`.
4. Close #252 when #284 lands.
5. Pin `release.yml` (#250, owner only).
6. Record CHR-55 on device (owner only).

Earlier state lines, newest first:

- 5:30 AM: `main` is still at `a344a8d` and green (no merges since 12:02 AM ET). 23 PRs are open; `scripts/pr-overlap.sh --entropy` (#396) scored 41 before this pass (21 open, 8 overlapping pairs, 1 conflicted, 2 with unresolved threads). New: #407 (damaged memory importance loads as a finite 0...1 score) and #408 (Ask Nexus intent input capped at 2,000 characters). #403 now scrolls the single-column portal grid at accessibility sizes. #392's CHR-55 summary has a golden format and an explicit "not an acceptance claim" line. Current focus: entropy reduction and CHR-55 device evidence, the sole critical path. CHR-55 is `not_recorded`.
- 12:10 AM: `main` is at `a344a8d`. Three guard PRs landed by squash since 1 PM: #397 (only MercuryBrain sets VisualState), #400 (network I/O stays in reviewed clients), #401 (UserDefaults stays in reviewed stores). Open: #404 (FoundationModels confined to the on-device adapter), #405 (file writes confined to reviewed stores), #403 (Sanctum audit settle; one open review thread on scrolling at accessibility sizes). Current focus: entropy reduction and CHR-55 device evidence, the sole critical path. CHR-55 is `not_recorded`.
- 1 PM: `main` was at `3dd53ce` (an owner docs note) and green. 20 PRs are open, and all are green except #374, which conflicts with `main`. #395 is folded into #392, and #387 is closed because #373 carries the same change. New guards: #400 keeps network I/O in the reviewed clients, and #401 keeps UserDefaults in the reviewed settings stores and bans iCloud key-value sync. Branch report (#391's script): 18 branches have no open PR. 3 are on the keep-list. None are fully in `main`. 2 are fully carried by an open PR (`feat/device-run-stamp-validation` in #392, `test/ui-smoke-main-actor` in #373) and become delete candidates once those merge. The other 13 are unmerged work for the owner to decide. CHR-55 is `not_recorded`.
- 9 AM: `main` is still at `6b1912c` (no merges since `ba0ecd6` other than the owner's docs note, so no regressions). 20 PRs are open. #390 was closed by the owner. Compiler warnings on `main`: 57 unique, all in `UITests/SanctumSmokeTests.swift` (main-actor isolation), and #387 already fixes them. SwiftLint warnings: 0. This morning's UI Smoke "Text clipped" flake was the scaled "Planetarium" portal label. #373 removes that `minimumScaleFactor` label scaling and switches to wrapping with fewer columns, and its head is green. New: #399, which checks every ship-version stamp in the docs against project.yml.
- 8 AM: `main` is at `6b1912c`, the owner's mirrored audit note. CI run 40187158661 on it failed only on the known UI Smoke "Text clipped" flake (`testSanctumAccessibilityAudit`), and the failed job was rerun once. 20 PRs are open, with 8 overlapping pairs. New since 6 AM: #397 (a VisualState ownership guard test) and #398 (an AGENTS.md focus-line refresh). #390's conflict with `main` is resolved: the owner's note stays as it is, and the Quicksilver log is now `QS-AUDIT-2026-10-25.md`.
- 6 AM: score about 7.5–7.7 (the owner says 7.5 and the agent 7.7; see AUDIT-2026-10-25.md). `main` is at `ba0ecd6` and green ([run 40102717768](https://github.com/cknowlesbadluck/QuicksilverV1/actions/runs/40102717768)). CHR-55 is `not_recorded` and is the only critical gate. 18 PRs are open. #374 is the only one that conflicts with `main`. New since 4 AM: #395 (stamp schema version and validation, stacked on #392) and #396 (a read-only PR-overlap report). #377's review fixes are pushed. The `@unchecked Sendable` and `nonisolated(unsafe)` ratchets are in #394. Every action in `ci.yml` is SHA-pinned, and `release.yml` (#250) is still tag-pinned. Merged this cycle: #381, #385 and #386.

## Platform maturity view (2026-10-25, 1 PM ET)

The same 10 phases, framed as how mature Quicksilver is as an iOS intelligence platform. Public Apple APIs only, free tooling only. Each exit criterion must hold on `main` with CI green. Device items count only when the owner records them.

1. **Device truth (CHR-55).** Exit: the owner records an Archive IPA run on iPhone 16e / iOS 27 with every `DeviceRunStamp` check passed. Until then `deviceAcceptance` stays `not_recorded`, and no code or doc claims otherwise.
2. **On-device Foundation Models routing.** Exit: on-device is tried first whenever the model is available. Every `OnDeviceModelAvailability` case has a tested fallback. The `needsCloud` planner keeps personal turns local, and the context budget is enforced by tests.
3. **App Intents, Shortcuts and Spotlight reach.** Exit: note find and save intents ship. Spotlight indexing is opt-in and removable (#377), with index cleanup tested. Every intent runs without opening the app UI where Apple allows it.
4. **Memory.** Exit: retention and load-time ceilings are enforced at the cap (#382, #388). Failures surface to the user (#314). Every store has a bound, including `IntegrationEventStore`.
5. **Sensing.** Exit: every SENSE input (network path, environment, aspect continuity) feeds the brain through a tested seam. Nothing reads sensors from views.
6. **Personas and aspects.** Exit: each aspect's default visual state and voice is covered by a test. Only MercuryBrain sets `VisualState` (#397), and the persona prompts have budget tests.
7. **Privacy floor.** Exit: logging is private by default (guarded). Keychain items are device-only (guarded). Network I/O stays in the reviewed clients (#400), and UserDefaults stays in the reviewed settings stores with no iCloud sync (#401). Cloud fallback prunes personal history (#342).
8. **Accessibility.** Exit: UI Smoke's accessibility audit passes 10 runs in a row without a rerun. Dynamic Type snapshots at accessibility5 are committed (#373), and motion always respects Reduce Motion through `MotionTokens`.
9. **Reliability and observability.** Exit: CI flakes are below 1 in 20 runs, and each known flake is tracked to its cause. Diagnostics are content-free (#374, #392), and `@unchecked Sendable` / `nonisolated(unsafe)` only shrink (#394).
10. **SideStore distribution.** Exit: an unsigned IPA builds from a script (#375), the docs match project.yml's version (#399), and `release.yml` actions are SHA-pinned (#250, owner only).

## 1.0 exit criteria, in order (CHR-55 first)

1. **CHR-55 is `recorded` by the owner.** Every item on the device checklist below passes on one build, with a content-free device-run stamp attached. Nothing else counts toward 1.0 until this holds.
2. Quicksilver CI is green on `main` on all 6 jobs for 20 consecutive runs, with no reruns.
3. The privacy floor guards are on `main`: logging (#370), Keychain policy (#385) and public API (#386). The diagnostics export is verified by the privacy gate (#374).
4. The memory budget, retention and load-time ceiling tests are on `main` (#382, #388).
5. The accessibility audit passes at xxLarge, xxxLarge and AX5 (#373).
6. Open PRs number fewer than 10, with no PR older than 7 days unless it is owner-held.

## Phase 1: CHR-55 device fence
- **Goal:** prove on real hardware what CI can only simulate.
- **Owner device checklist.** The owner runs it on an iPhone 16e with iOS 27, all on the same build:
  1. Get the unsigned IPA, then sign and install it through SideStore. Until #375 lands, the IPA comes from the existing `Archive IPA` workflow, which the owner triggers. After #375, the owner can build it locally with that PR's `scripts/` and `docs/SIDESTORE.md`. Agents never run the archive or signing steps.
  2. **Cold launch:** force-quit, launch, and the Sanctum appears with no crash.
  3. **On-device answer:** with Apple Intelligence on and airplane mode on, Ask answers on-device.
  4. **Keychain after a reboot:** reboot, unlock, and open the app. Stored keys are present, routing rebuilds, and nothing has to be re-entered. (A passcode-protected iPhone can't open the app before its first unlock. The locked state itself is covered on CI by the injected Keychain failure in `CredentialsLockedPairingTests`, not by this step.)
  5. **Spotlight tap:** opt in to Spotlight, save a note, search for it in Spotlight, and tap it. The Archive opens on that note. Then opt out and confirm the note is gone from Spotlight.
  6. **VoiceOver:** VoiceOver can reach Sanctum, Ask, Archive and Codex, and every control has a label.
  7. **Memory at the cap:** with about 1,000 turns plus 500 notes, launch to a usable Sanctum within a few seconds. Notes survive a relaunch, and the oldest note is still findable.
- **Implementations:** a content-free "device run" stamp (build, OS, hardware identifier, model availability, timings and a result for each step). The type is `DeviceRunStamp` in #392 and always reads `not_recorded`. Next, a Codex control lets the owner record step results and export the stamp next to the diagnostics export (#374).
- **Exit:** every checklist item passes, and the owner sets CHR-55 to `recorded` with the stamp attached. Until then, every later phase that depends on device behaviour stays provisional.

## Phase 2: memory budget
- **Goal:** memory stays bounded and fast at the cap.
- **Implementations:**
  - Retention is already tested (`MemoryBudgetTests`).
  - Load-time test at 1,000 turns plus 500 notes, with 15 s load and 5 s query ceilings (#388, green). On CI, load took about 2–5 ms with the in-memory store and 0.09–0.22 s with SwiftData.
  - Every note query filters before it caps (done for `memoryNotes` in #377).
  - Retention runs incrementally on save rather than as a full sweep.
- **Exit:** budget, retention and benchmark tests pass on CI. A device load time at the cap is recorded after CHR-55.

## Phase 3: privacy floor
- **Goal:** personal data never leaves the device unless the gate allows it, and every privacy control fails visibly.
- **Implementations:**
  - Land the cloud-fallback history prune (#342, green; it now contains #340's classifier corpus). The NaturalLanguage gate from the closed #319 can be recovered from commit `4b40a2a`; the steps are noted on #342.
  - Rebase and land the content-free diagnostics export (#374).
  - Keychain items stay `ThisDeviceOnly`, with a test.
  - Logs stay private by default (`LoggerPrivacyGuardTests`).
  - Spotlight opt-out failures are surfaced (#377).
  - A single "privacy ledger" Codex row lists what is on-device, indexed or cloud-eligible.
- **Exit:** all of the above are merged. Non-English input fails closed, and the ledger matches a test-asserted inventory.

## Phase 4: on-device Foundation Models routing
- **Goal:** on-device answers first, with the cloud as a gated fallback.
- **Implementations:**
  - A per-aspect routing policy, with the reason for each route kept in the content-free route log.
  - Prewarm on Sanctum appear and drop the warm session on memory pressure.
  - A deterministic availability seam in all UI tests (as in #373's snapshot).
- **Exit:** the routing matrix tests cover available, not eligible, preparing and off. Cloud is reached only through the gate.

## Phase 5: deeper aspect instruments
- **Goal:** each aspect has an instrument that is useful offline.
- **Implementations:**
  - Aspect-specific on-device tools through Foundation Models tool calling, for example note recall, a timeline of saved notes and a device-health readout from Nexus.
  - Each instrument is a pure function over memory or Nexus, with unit tests.
- **Exit:** every aspect has one instrument with tests, and none needs the network.

## Phase 6: Spotlight, Shortcuts and App Intents
- **Goal:** system surfaces show notes only, with user consent.
- **Implementations:**
  - Find in My Notes and Forget a Note (confirm plus unlock). Their old PRs #337 and #343 were closed as stale and overlapping #377; rebuild them on top of #377 once it lands.
  - Tapping a Spotlight result opens the note through `CSSearchableItemActionType`: `NoteSpotlightRoute` sends the tap to the Archive, which scrolls to and highlights the note, with unit tests (#377).
  - App Shortcuts phrases.
- **Exit:** intent and Spotlight tests prove that chat turns are never exposed, a result tap reaches the note in a UI test, and Forget requires unlock.

## Phase 7: accessibility
- **Goal:** usable at every Dynamic Type size and with VoiceOver.
- **Implementations:**
  - Run the UI audit at large non-accessibility sizes (xxLarge, xxxLarge) as well as AX5. The Sanctum scrolls from xxLarge up (#373, rebased; it also contains #387).
  - Use opaque readable colours only (#381).
  - Make snapshots deterministic (pinned model state and a frozen-time Sanctum render).
- **Exit:** the audit passes at three sizes on CI, and snapshots compare against baselines, with no record-only cases left.

## Phase 8: reliability
- **Goal:** no flaky CI, and no silent failures.
- **Implementations:**
  - Retire the remaining `@unchecked Sendable` sites (#252) through the ratchet.
  - The memory failure banner (#314, green).
  - Main-actor UI smoke tests with no concurrency warnings (#387, green), and a settled-Sanctum wait for the Workshop contrast flake (#373).
  - Thread Sanitizer stays required.
  - Quarantine and fix any test that fails twice in 20 runs.
- **Exit:** 20 consecutive green `main` runs, and the ratchet is at zero.

## Phase 9: observability
- **Goal:** the owner can diagnose problems without seeing content.
- **Implementations:**
  - Signpost intervals for launch, memory load, routing and Spotlight sync.
  - A content-free metrics page in the Codex.
  - Export a diagnostics bundle that the privacy gate has verified.
- **Exit:** every major path has a signpost, and the export passes the privacy-gate test.

## Phase 10: SideStore distribution
- **Goal:** a reproducible, unsigned IPA that the owner signs and installs through SideStore.
- **Implementations:**
  - The local IPA script and `docs/SIDESTORE.md` (#375).
  - Release notes generated from merged PRs.
  - Signing and release workflows stay owner-only.
- **Exit:** the owner installs a 1.0 build through SideStore after CHR-55 is recorded. Agents never run the archive or release workflows.
