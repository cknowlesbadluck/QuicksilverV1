# Portfolio 10-phase roadmap — refreshed 2026-10-26, 2:00 AM ET (hygiene prune, CHR-55 gate, innovation)

Evidence block (details in [AUDIT-2026-10-26.md](AUDIT-2026-10-26.md)):
- Conduit: ready OK, owner-reported probe (~06:00Z / 2:00 AM ET 2026-10-26) — 0.8.0, postgres, production true, diagnostics all green.
- Resonance: ready OK, owner-reported probe (~06:00Z / 2:00 AM ET 2026-10-26) — missingRequired=[], production true, posture contract_passed, contractRevision=2026-10-03-owner-gate.
- Open PRs: QuicksilverV1 20 (verified live 2026-10-26, matches owner figure), Conduit 15 and Resonance 24 (owner-reported probe (~06:00Z / 2:00 AM ET 2026-10-26)).
- CHR-55: open. deviceAcceptance=not_recorded.
- Alias drift: persists (owner-reported probe (~06:00Z / 2:00 AM ET 2026-10-26)). Some hosting aliases still resolve to an unexpected occupant with no service stamp. Non-blocking, elevated.
- QuicksilverV1 main a344a8d, Quicksilver CI green.
- Classifier or probe output is not production proof. No device claim. No secrets recorded.

Binding constraint: CHR-55 device evidence is the sole remaining production gate. Everything else is hygiene or hardening.

## Phase 1 — Owner gate cleared
Exit met and still holding: Resonance ready body stamped, missingRequired=[], posture contract_passed. Do not invent keys. Any regression fails closed (not ready).

## Phase 2 — Alias and stranger classification stay strict
404 and unexpected 200 occupants are never the gate and never count as ready. Exit: tests reject treating them as owner action, device recorded, or production ready. Alias cleanup is owner work.

## Phase 3 — Device fence immutable
Exit: health and run-stamp output keep deviceAcceptance=not_recorded and acceptanceGate=CHR-55 (QS #392 adds an exhaustive guard). Nothing in code may write any other value.

## Phase 4 — CHR-55 is the sole remaining production gate
Simulator, CI, or probe 200 is not acceptance. Exit: CHR-55 closed only by the owner after an archived build is installed and validated on a real device. Until then acceptance stays not_recorded.

## Phase 5 — Conversation and Memory budget stay
Bounded windows and on-device embeddings. Exit: unit tests green; no unbounded history leakage.

## Phase 6 — Gateway contract and free tier stay
No paid services or bindings. Exit: config review clean.

## Phase 7 — Hygiene prune to <10 open QuicksilverV1 PRs
Exit criteria, all required:
1. Open QS PR count < 10 (now 20).
2. Every remaining open PR is CI-green or carries a one-line blocker in its body.
3. No two open PRs edit the same file unless one is explicitly stacked (`scripts/pr-overlap.sh` reports zero unplanned overlaps).
4. Superseded docs-only PRs closed with the standard hygiene comment; branches kept.
5. Merges are owner-approved squash merges of green, non-overlapping PRs only.
Conduit (15) and Resonance (24) follow the same <10 target.

## Phase 8 — Resonance control plane stamped
Ready body carries the contract stamp. New surfaces advance only under existing constraints (no device claim, privacy floor).

## Phase 9 — Privacy and logging stay strict
Cloud routing fails closed; privacy floors can only tighten remotely. Logs are metadata only. Exit: no request/response body logging; secret scan of tracked files clean (test fixtures only).

## Phase 10 — Cross-plane acceptance proof
One probe covers Conduit ready, Resonance ready (stamped), and real-device evidence for CHR-55. Exit: owner accepts the production verdict. Fixtures or classifiers are insufficient. Device remains open.

## Innovation track (no gates relaxed)
1. Cross-plane readiness probe v2: one read-only report of both planes plus QS main CI, failing closed on any missing, stale, or unstamped field.
2. Automated hygiene score: open-PR count, overlap count, and merge candidates from `scripts/pr-overlap.sh --candidates` (QS #396).
3. Stale-branch report (QS #391) feeding branch-prune candidates; report only, deletion stays owner-only.
4. Surface guards as ratchets: allowlists that fail on new offenders and on stale entries.
5. Device run stamp (QS #392) as the content-free format for future CHR-55 evidence.

Highest-value next: record CHR-55 device evidence on a real device; in parallel prune QS open PRs below 10.
