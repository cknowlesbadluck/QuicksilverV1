# Portfolio 10-phase roadmap — 2026-10-15 06:00 EDT

Quicksilver main green. 18 open PRs (many drafts, owner-rule do-not-merge). CHR-55 sole hard gate.

## Phase 1 — Owner / device fences
CHR-55 remains immutable. Simulator never counts as acceptance.

## Phase 2 — PR queue hygiene
Use pr-queue-status.sh. Close or stack superseded drafts. Exit: open PR count <10, no conflicting bases.

## Phase 3 — Land green hardening
Merge MainActor monitor fixes, Sendable logger, module boundary tests, bundle hardening tests. Exit: CI still green, fewer @unchecked.

## Phase 4 — Memory bounds and recall
Land bounded retention + on-device recall (zero model call). Exit: AppTests prove no unbounded growth and memory provenance.

## Phase 5 — Provenance and failure matrix
Land answer provenance badge + Brain failure matrix tests. Exit: UI shows On device / Cloud, failures leave .warning not stuck.

## Phase 6 — A11y and performance
Sanctum hit area + pause TimelineViews. Exit: a11y audit clean on Sanctum.

## Phase 7 — Gateway free-tier completion
Finish M3 routing (on-device first, Gemini minimal context). Exit: fake provider covers failover in CI.

## Phase 8 — Apple Intelligence seam
FoundationModels behind AIProvider, #available gate. Exit: offline answers when available.

## Phase 9 — Invocation redesign start
Begin non-chat Ask surface. Exit: one vertical slice, no generic bubbles.

## Phase 10 — Device acceptance proof
Archive IPA installed and validated on iPhone 16e. CHR-55 closed. Cross-plane probe green.

Innovation: on-device embeddings for MemoryQuery, App Intents tools registry, visual controlled-chaos polish under HG-P.
