# CHR-55 device acceptance test (iPhone 16e)

Christopher runs this on his own iPhone 16e. **Only real results from that device count.** Agents
never fill in this table, and simulator or CI results are not evidence for CHR-55.

- **Time:** about 60–90 minutes.
- **Record before starting:** the build being tested (app version, build number and commit, from Codex → Export diagnostics, step 10.1), the iOS version, and whether Apple Intelligence is on.
- **Mark each step:** Pass, Fail or N/A (feature not in this build). For Fail, write what happened.
- **Never paste** personal content, keys or tokens into the results.

Steps that need an unmerged PR are tagged, for example *(needs #337)*. Mark them N/A if the build doesn't include that PR.

## 0. Prerequisites

| # | Check | Pass criteria |
|---|---|---|
| 0.1 | Unsigned IPA built locally with `scripts/build-unsigned-ipa.sh` *(needs #328)*, or by the Archive IPA workflow | The script or the run prints the IPA path, version (build) and SHA-256; record all three |
| 0.2 | SideStore installed and refreshed on the iPhone 16e | SideStore opens; the Apple ID is signed in |
| 0.3 | Battery above 50%, Low Power Mode off, Wi-Fi on | As stated |

## 1. Install and launch (SideStore)

| # | Step | Pass criteria |
|---|---|---|
| 1.1 | AirDrop or Files the IPA to the phone and install it with SideStore | Installs with no error; the Quicksilver icon appears |
| 1.2 | Cold launch | The Sanctum appears within 3 s; no crash; the core animates |
| 1.3 | Force-quit and relaunch 3 times | No crash; same state each time |
| 1.4 | Refresh the app in SideStore, then launch | Still launches; saved notes are still there (check after section 6) |

## 2. On-device answers

| # | Step | Pass criteria |
|---|---|---|
| 2.1 | Codex → Mind status | Shows on-device available (iOS 26+ with Apple Intelligence on), or a clear reason it isn't |
| 2.2 | Ask: "Explain photosynthesis in two sentences" | An answer appears; the badge/provenance says on device |
| 2.3 | Codex → Recent routes | The last turn is listed as on-device, with no prompt text shown |
| 2.4 | Background the app mid-answer, then return | No crash; the answer completes or ends cleanly with a calm message |

## 3. Privacy

| # | Step | Pass criteria |
|---|---|---|
| 3.1 | Turn on Airplane mode. Ask: "What is the capital of Peru?" | Answered on device, or a calm offline message. No hang, no crash |
| 3.2 | Still in Airplane mode, ask: "My doctor changed my medication, what should I ask her?" | Answered on device or kept on device. It never says it used the cloud |
| 3.3 | Airplane mode off, with a cloud route bound. Ask a personal prompt ("my rent went up again, what should I do?") | Recent routes shows on-device or kept on device, **not** cloud |
| 3.4 | Ask "my knee hurts", then "What is the capital of Peru?" *(needs #342 for the second part)* | The personal turn never shows as cloud. The knowledge question may use the cloud only if on-device failed |
| 3.5 | Codex → Export diagnostics, then read the text | No prompt, reply, note text or key values; counts and states only |

## 4. App Intents and Siri

| # | Step | Pass criteria |
|---|---|---|
| 4.1 | Siri: "Remember this in Quicksilver", then say "Spare key is under the blue pot" | Siri confirms "Captured: …" |
| 4.2 | Siri: "What aspect is active in Quicksilver" | An aspect name is spoken; the app doesn't open |
| 4.3 | Siri: "Find in my notes in Quicksilver", then say "spare key" *(needs #337)* | While locked it asks you to unlock; once unlocked it reads one matching note |
| 4.4 | Shortcuts app → Forget a Note → pick the spare-key note *(needs #343)* | It asks for confirmation first; after confirming, the note is gone from the Memory screen |
| 4.5 | Codex → "Show notes in Spotlight" on, then search "spare" in Spotlight *(needs #330)* | The note appears. Turn the toggle off and the note disappears from Spotlight |

## 5. Dynamic Type and VoiceOver

| # | Step | Pass criteria |
|---|---|---|
| 5.1 | Settings → Accessibility → Larger Text at maximum (AX5). Open the Sanctum | Nothing is cut off or overlapping; content scrolls; "SANCTUM" isn't split *(needs #324)* |
| 5.2 | Codex at AX5 | All rows readable; toggles reachable |
| 5.3 | Turn on VoiceOver and swipe through the Sanctum | Every control has a sensible label; the core reads "Speak with Quicksilver" |
| 5.4 | With VoiceOver on, ask a question *(needs #344)* | You hear "Thinking", then "Answer ready", without repeated chatter |
| 5.5 | Reduce Motion on | Ambient motion stops or becomes a fade; no spinning or orbiting |

## 6. Memory

| # | Step | Pass criteria |
|---|---|---|
| 6.1 | Memory screen after 4.1 | The note is listed |
| 6.2 | Ask: "What did I tell you about the spare key?" | Answered from memory, with a "From memory" badge |
| 6.3 | Delete the note on the Memory screen | It's gone and doesn't come back after a relaunch |
| 6.4 | Save a note, wait 2 days or more, then check again | The note is still present (notes are never auto-pruned) |

## 7. Low Power Mode and thermal

| # | Step | Pass criteria |
|---|---|---|
| 7.1 | Low Power Mode on, Sanctum open for 2 min | The app stays responsive; ambient motion visibly slows *(needs #339)* |
| 7.2 | Diagnostics screen with Low Power Mode on | Battery or low-power state shown |
| 7.3 | After 10 min of use, feel the phone and check battery use in Settings | Not hot; Quicksilver's battery use is reasonable for the time spent |

## 8. Network loss and the gateway (only if a gateway is bound)

| # | Step | Pass criteria |
|---|---|---|
| 8.1 | Start a cloud answer, then toggle Airplane mode | A calm error; partial text kept or cleared; no crash |
| 8.2 | Codex → Cloud budget row | Shows remaining/limit, or "not reported" |

## 9. Stability

| # | Step | Pass criteria |
|---|---|---|
| 9.1 | Use the app normally for 15 min (ask, realms, Memory, Codex) | No crash, freeze or blank screen |
| 9.2 | Settings → Privacy & Security → Analytics Data: search for "Quicksilver" | No new crash logs (record their names if any) |

## 10. Diagnostics export

| # | Step | Pass criteria |
|---|---|---|
| 10.1 | Codex → Export diagnostics → share to Notes | It shares; the version and build match 0.1; no content or keys |

## Results (fill in on device)

| Field | Value |
|---|---|
| Date / time (ET) | |
| Device / iOS version | iPhone 16e / |
| Apple Intelligence on? | |
| App version (build) / commit | |
| IPA SHA-256 | |

| Step | Pass / Fail / N/A | Notes |
|---|---|---|
| 0.1 | | |
| 0.2 | | |
| 0.3 | | |
| 1.1 | | |
| 1.2 | | |
| 1.3 | | |
| 1.4 | | |
| 2.1 | | |
| 2.2 | | |
| 2.3 | | |
| 2.4 | | |
| 3.1 | | |
| 3.2 | | |
| 3.3 | | |
| 3.4 | | |
| 3.5 | | |
| 4.1 | | |
| 4.2 | | |
| 4.3 | | |
| 4.4 | | |
| 4.5 | | |
| 5.1 | | |
| 5.2 | | |
| 5.3 | | |
| 5.4 | | |
| 5.5 | | |
| 6.1 | | |
| 6.2 | | |
| 6.3 | | |
| 6.4 | | |
| 7.1 | | |
| 7.2 | | |
| 7.3 | | |
| 8.1 | | |
| 8.2 | | |
| 9.1 | | |
| 9.2 | | |
| 10.1 | | |

**CHR-55 closes** when sections 0–3, 6, 9 and 10 all pass (or are N/A only because the feature isn't in the build), and Christopher signs off below.

Signed off by: ____________________ Date: __________
