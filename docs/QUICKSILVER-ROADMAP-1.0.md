# QuicksilverV1 roadmap to 1.0

QuicksilverV1 only. Each phase has a goal, implementations and exit criteria. A phase is done when its exit criteria hold on `main` with Quicksilver CI green on all 6 jobs. Device evidence counts only if the owner records it. Agents never record or claim it.

**State as of 2026-10-24, 8 PM ET:** score about 7.6. `main` is at `ba0ecd6` and green ([run 40102717768](https://github.com/cknowlesbadluck/QuicksilverV1/actions/runs/40102717768)). CHR-55 is `not_recorded` and is the only critical gate. 13 PRs are open. Merged this cycle: #381, #385 and #386. Closed with branches kept: #319, #337, #340, #343, #345, #348 and #389 (folded into #390).

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
  1. Build the unsigned IPA locally (`scripts/` and `docs/SIDESTORE.md` from #375), then sign and install it through SideStore. Agents never run the archive or signing steps.
  2. **Cold launch:** force-quit, launch, and the Sanctum appears with no crash.
  3. **On-device answer:** with Apple Intelligence on and airplane mode on, Ask answers on-device.
  4. **Keychain after a reboot:** reboot, then open the app before the first unlock and confirm the Codex shows the locked state. Unlock and confirm routing rebuilds, with stored keys present and nothing re-entered.
  5. **Spotlight tap:** opt in to Spotlight, save a note, search for it in Spotlight, and tap it. The Archive opens on that note. Then opt out and confirm the note is gone from Spotlight.
  6. **VoiceOver:** VoiceOver can reach Sanctum, Ask, Archive and Codex, and every control has a label.
  7. **Memory at the cap:** with about 1,000 turns plus 500 notes, launch to a usable Sanctum within a few seconds. Notes survive a relaunch, and the oldest note is still findable.
- **Implementations:** the app adds a content-free "device run" stamp to the diagnostics export (build, OS, model availability, timings) for the owner to attach.
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
