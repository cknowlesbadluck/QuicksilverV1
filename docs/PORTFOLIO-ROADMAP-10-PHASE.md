# Portfolio 10-phase roadmap — refreshed 2026-10-22 20:05 UTC (full audit + harden + stabilize + hygiene prune + innovate)

Live probes 2026-10-22T20:02Z:
- Conduit /ready: **ready OK** (200 stamped, version 0.8.0, contractRevision 2026-10-03-ready-surface, persistence postgres).
- Resonance /api/ready: **not_ready FAIL** (HTTP 503, missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"]). Owner gate preserved. No secret invented.
- Vercel aliases: resonance.vercel.app 200 (stranger_occupant FAIL DRIFT), quicksilver.vercel.app 200 (stranger_occupant), resonancenexus.vercel.app 404 (alias_absent), quicksilverv1.vercel.app 404 (alias_absent).
- Portfolio maturity score: ~3.3/10 on strict probe (drift + fail-closed). Overall portfolio ~5.5-6.0/10. Stabilization holds.
- Supabase projects INACTIVE (owner gate).
- Open PR entropy: QuicksilverV1 ~22, Resonance ~30, Conduit ~28. Hygiene prune in progress (closed superseded docs PRs #232 Resonance, #277 Conduit).
- No device claim (CHR-55 open). Classifier ≠ production proof. No secrets exposed.

Brutal maturity: Dominant risks remain external owner gates (SUPABASE key + CHR-55 device IPA on real iPhone 16e) + open-PR entropy. Fail-closed posture confirmed. High entropy is operational drag.

## Phase 1 — Owner gate stays external
Do not invent or store SUPABASE_SERVICE_ROLE_KEY. Exit: live ready body remains owner-blocked; posture parser rejects any other classification.

## Phase 2 — Alias and stranger classification stay strict
404 and unexpected 200 occupants are never the gate. Exit: tests reject treating them as owner action, device recorded, or production ready. Drift on Vercel aliases noted — cleanup recommended but not blocking.

## Phase 3 — Device fence immutable
claimDeviceAcceptance() rejects. Exit: health body keeps deviceAcceptance=not_recorded and acceptanceGate=CHR-55.

## Phase 4 — CHR-55 remains the only device gate
Simulator, CI, or workers.dev 200 is not acceptance. Exit: Linear CHR-55 open until archive IPA installed and validated on iPhone 16e.

## Phase 5 — Conversation and Memory budget stay
Bounded windows and on-device embeddings continue. Exit: AppTests green; no unbounded history leakage.

## Phase 6 — Gateway contract and free-tier stay
No paid Workers bindings (KV/R2/D1/Queues). Exit: wrangler.toml / equivalent clean.

## Phase 7 — Hygiene prune executed
One roadmap file. No hourly audit artifacts. Held PRs not merged without verification. Archived Quicksilver remains non-product. Superseded docs-refresh PRs closed. Open PR count target below 10 per repo via prioritized merge of green non-overlapping hardens and close of superseded/docs-only. Audit note mirrored across repos.

## Phase 8 — Resonance control plane waits on stamp
No second client or iOS Resonance surface until live Netlify ready body carries contract stamp and owner key is set.

## Phase 9 — Privacy and logging stay strict
Privacy manifest enforced. Gateway logs metadata only. Exit: no request/response body logging.

## Phase 10 — Cross-plane acceptance proof
Single probe covers Conduit ready (already true), Resonance ready (stamped), and real device archive evidence. Exit: production verdict accepted. Fixture or classifier test is insufficient.

Binding constraints: Resonance owner secret + CHR-55 device archive. Neither is closed by simulator or classifier. High open-PR entropy remains the current operational risk and must be pruned first.

## Innovation Track (advanced — no gates violated)
1. Pure PortfolioPosture classifier holds. Fail-closed. Maturity score added to probe.
2. portfolio-probe tools with cold-start backoff — continue.
3. Hygiene prune priority: close superseded docs-only PRs aggressively; merge only CI-green non-overlapping hardens.
4. Adversarial review of recent hardens continues.
5. Cross-plane readiness contract v1 alignment across repos.
6. Lockfile / Dependabot residual hygiene.
7. Cross-repo consistency: this evidence block is canonical; mirror key notes.
8. Chamber and capability plane advances held pending no-gate confirmation.
9. On-device diagnostics post Phase 8 only.
10. Fresh probe confirms identical fail-closed posture. No regression. Drift detections elevated for alias cleanup.
11. Stale branch detector (Conduit #278) for automated hygiene.

Highest-value next: aggressively reduce open PR entropy (docs notes first, then non-overlapping green hardens), then owner gates (SUPABASE key + CHR-55 IPA). Stabilization holds. Innovate continues under constraints. Probe maturity score now live for quantitative tracking.
