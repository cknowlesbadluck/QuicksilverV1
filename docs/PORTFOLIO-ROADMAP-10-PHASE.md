# Portfolio 10-phase roadmap — refreshed 2026-10-26 ~07:00 UTC (hygiene prune + CHR-55 sole gate + innovate)

Evidence (see AUDIT-2026-10-26.md):
- Resonance: ready OK (07:00Z probe) — contract_passed, missingRequired=[], production true.
- Conduit: 503 cold-start (expected free-tier; prior ready). Distinguish cold-start from not-ready.
- Open PRs: QS ~20, Conduit 15, Resonance 24. Target <10 each.
- CHR-55: open. deviceAcceptance=not_recorded. Sole production gate.
- Alias drift: persists. Non-blocking.
- No device claim. Classifier ≠ production proof. No secrets.

Brutal maturity: ~7.2/10. Dominant risks: CHR-55 + PR entropy. Stabilization holds.

## Phase 1 — Owner gate cleared
Exit met. Resonance stamped. Regression fails closed.

## Phase 2 — Alias and stranger classification stay strict
Unexpected occupants never ready. Exit: tests enforce.

## Phase 3 — Device fence immutable
claimDeviceAcceptance rejects. deviceAcceptance=not_recorded.

## Phase 4 — CHR-55 sole remaining production gate
Only real device Archive IPA on iPhone 16e/iOS 27 closes it. Simulator/CI/probe insufficient.

## Phase 5 — Conversation and Memory budget stay
Bounded. Tests green.

## Phase 6 — Gateway contract and free tier stay
No paid bindings. Cold-start 503 retryable.

## Phase 7 — Hygiene prune to <10 open PRs per repo
Exit:
1. QS open PRs <10 (from ~20).
2. Remaining are CI-green or explicitly blocked.
3. Zero unplanned file overlaps.
4. Superseded docs-only closed.
5. Owner-approved squash of green non-overlapping only.
Same for Conduit/Resonance.

## Phase 8 — Resonance control plane stamped
Holds. New surfaces under constraints.

## Phase 9 — Privacy and logging stay strict
Fail-closed routing. Metadata-only logs. Secret scan clean.

## Phase 10 — Cross-plane acceptance proof
Probe + real device evidence. Owner verdict. Device open until then.

## Innovation track (no gates relaxed)
1. Cross-plane readiness probe v2 with cold-start distinction and QS CI.
2. Automated hygiene score (PR count, overlaps, candidates) via scripts.
3. Stale-branch report (report-only).
4. Surface guards as ratchets.
5. Content-free DeviceRunStamp for future CHR-55 evidence.
6. Aggressive prune of docs entropy itself.

Highest-value next: prune open PRs below 10 across portfolio; record CHR-55 device evidence. Stabilization holds. Innovate under constraints.
