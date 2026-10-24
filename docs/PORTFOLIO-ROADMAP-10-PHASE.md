# Portfolio 10-phase roadmap — refreshed 2026-10-24 06:00 UTC (full audit + harden + stabilize + hygiene prune + innovate)

Live probes 2026-10-24T06:00Z:
- Conduit https://conduit-feco.onrender.com/ready : **ready OK** (HTTP 200, version 0.8.0, contractRevision=2026-10-03-ready-surface, persistence=postgres). Warm.
- Resonance https://resonancenexus.netlify.app/api/ready : **ready OK** (HTTP 200, missingRequired=[], production true, authMode required ok, persistenceConfigured true, posture=contract_passed, contractRevision=2026-10-03-owner-gate). Timestamp ~06:00:50Z. Owner gate cleared.
- Vercel aliases: resonance.vercel.app returns 200 HTML (stranger_occupant / no service stamp); resonancenexus.vercel.app 404 (alias_absent). quicksilver.vercel.app similar. Drift persists.
- Open PR counts: QuicksilverV1 14, Conduit 25, Resonance 44. Entropy reduced from prior ~18/27/45; hygiene prune ongoing, target <10.
- CI: recent main runs green across repos (QS CI in progress on latest dead-code prune, Conduit docs-hygiene success, Resonance typecheck/tests green).
- Portfolio maturity (probe classification): ~7/10. Both planes stamped ready. Remaining: CHR-55 device evidence + alias drift + residual PR entropy.
- No secrets invented. No device claim (CHR-55 open, deviceAcceptance=not_recorded). Classifier ≠ production proof.

Brutal maturity: portfolio ~7.0/10. Dominant risks now: CHR-55 device Archive IPA on iPhone 16e/iOS 27 + open-PR entropy + Vercel alias drift. Stabilization holds; fail-closed posture confirmed. Scores: QS ~7.6, Conduit ~7.4, Resonance ~6.8 (post-gate).

## Phase 1 — Owner gate cleared (external key set)
SUPABASE_SERVICE_ROLE_KEY no longer missing. Exit met: live ready body stamped, missingRequired=[], posture contract_passed. Do not invent keys.

## Phase 2 — Alias and stranger classification stay strict
404 and unexpected 200 occupants are never the gate. Exit: tests reject treating them as owner action, device recorded, or production ready. Drift on Vercel aliases prioritized for cleanup (non-blocking, elevated).

## Phase 3 — Device fence immutable
claimDeviceAcceptance() rejects. Exit: health body keeps deviceAcceptance=not_recorded and acceptanceGate=CHR-55.

## Phase 4 — CHR-55 remains the only device gate
Simulator, CI, or workers.dev 200 is not acceptance. Exit: Linear CHR-55 open until archive IPA installed and validated on iPhone 16e.

## Phase 5 — Conversation and Memory budget stay
Bounded windows and on-device embeddings continue. Exit: AppTests green; no unbounded history leakage.

## Phase 6 — Gateway contract and free-tier stay
No paid Workers bindings (KV/R2/D1/Queues). Exit: wrangler.toml / equivalent clean.

## Phase 7 — Hygiene prune executed
One roadmap file. No hourly audit artifacts. Held PRs not merged without verification. Archived Quicksilver remains non-product. Superseded docs-refresh PRs targeted for close. Open PR count target below 10 per repo via prioritized merge of green non-overlapping hardens and close of superseded/docs-only. Audit note mirrored across repos. Current: 14/25/44.

## Phase 8 — Resonance control plane stamped
Live Netlify ready body carries contract stamp. Second client or iOS Resonance surface may advance under existing constraints (no device claim, privacy floor).

## Phase 9 — Privacy and logging stay strict
Privacy manifest enforced. Gateway logs metadata only. Exit: no request/response body logging.

## Phase 10 — Cross-plane acceptance proof
Single probe covers Conduit ready (true), Resonance ready (stamped), and real device archive evidence. Exit: production verdict accepted. Fixture or classifier test is insufficient. Device remains open.

Binding constraints: CHR-55 device archive remains. High open-PR entropy and alias drift are current operational risks and must be pruned/cleaned.

## Innovation Track (advanced — no gates violated)
1. Pure PortfolioPosture classifier holds. Fail-closed. Maturity score added to probe.
2. portfolio-probe tools with cold-start backoff (retry on 503) — landed.
3. Open PR entropy reporting advances quantitative hygiene tracking.
4. Hygiene prune priority: close superseded docs-only PRs; merge only CI-green non-overlapping hardens.
5. Adversarial review of recent hardens continues.
6. Cross-plane readiness contract v1 alignment across repos (now both ready).
7. Lockfile / Dependabot residual hygiene.
8. Cross-repo consistency: this evidence block is canonical; mirror key notes.
9. Chamber and capability plane advances now unblocked by Resonance gate.
10. On-device diagnostics post CHR-55 only. Fresh probe confirms dual ready. No regression.

Highest-value next: aggressively reduce open PR entropy (close docs-only superseded first, merge green non-overlapping hardens), clean Vercel alias drift, then CHR-55 device IPA evidence. Stabilization holds. Innovate continues under constraints. Dual-plane ready is the new baseline.
