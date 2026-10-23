# Portfolio 10-phase roadmap — refreshed 2026-10-23 07:00 UTC (full audit + harden + stabilize + hygiene prune + innovate)

Live probes 2026-10-23T07:01Z:
- Conduit https://conduit-feco.onrender.com/ready : **ready OK** (HTTP 200, version 0.8.0, contractRevision=2026-10-03-ready-surface, persistence=postgres).
- Resonance https://resonancenexus.netlify.app/api/ready : **not_ready FAIL** (HTTP 503, missingRequired exactly [SUPABASE_SERVICE_ROLE_KEY], production true, authMode required ok, persistenceConfigured false).
- Vercel aliases: resonance.vercel.app and quicksilver.vercel.app return 200 HTML (stranger_occupant / no service stamp); resonancenexus.vercel.app / quicksilverv1.vercel.app alias_absent or drift.
- Open PR counts: QuicksilverV1 ~24, Conduit ~36, Resonance ~49. High entropy is the dominant operational debt after owner gates.
- Conduit diagnostics: health 200, protected resource, authorization server, JWKS, scopes all ok. CIMD/DCR advertised.
- CI: recent Quicksilver and Conduit main runs green. Resonance typecheck/tests previously green.
- Portfolio maturity (probe classification): ~4-5/10 due to Resonance owner gate + alias drift. Overall blunt score ~6/10 with stabilization holding.
- No secrets invented. No device claim (CHR-55 open, deviceAcceptance=not_recorded). Classifier ≠ production proof.

Brutal maturity: portfolio ~5.5-6.5/10. Dominant risks: external owner gates (SUPABASE_SERVICE_ROLE_KEY + CHR-55 device Archive IPA on iPhone 16e/iOS 27) + open-PR entropy. Stabilization holds; fail-closed posture confirmed. Free-tier cold-start tolerance expected but Conduit currently warm.

## Phase 1 — Owner gate stays external
Do not invent or store SUPABASE_SERVICE_ROLE_KEY. Exit: live ready body remains owner-blocked; posture parser rejects any other classification.

## Phase 2 — Alias and stranger classification stay strict
404 and unexpected 200 occupants are never the gate. Exit: tests reject treating them as owner action, device recorded, or production ready. Drift on Vercel aliases noted and prioritized for cleanup (non-blocking).

## Phase 3 — Device fence immutable
claimDeviceAcceptance() rejects. Exit: health body keeps deviceAcceptance=not_recorded and acceptanceGate=CHR-55.

## Phase 4 — CHR-55 remains the only device gate
Simulator, CI, or workers.dev 200 is not acceptance. Exit: Linear CHR-55 open until archive IPA installed and validated on iPhone 16e.

## Phase 5 — Conversation and Memory budget stay
Bounded windows and on-device embeddings continue. Exit: AppTests green; no unbounded history leakage.

## Phase 6 — Gateway contract and free-tier stay
No paid Workers bindings (KV/R2/D1/Queues). Exit: wrangler.toml / equivalent clean.

## Phase 7 — Hygiene prune executed
One roadmap file. No hourly audit artifacts. Held PRs not merged without verification. Archived Quicksilver remains non-product. Superseded docs-refresh PRs targeted for close. Open PR count target below 10 per repo via prioritized merge of green non-overlapping hardens and close of superseded/docs-only. Audit note mirrored across repos. Automated open-PR entropy reporting in portfolio-probe (Conduit #282) advances this.

## Phase 8 — Resonance control plane waits on stamp
No second client or iOS Resonance surface until live Netlify ready body carries contract stamp and owner key is set.

## Phase 9 — Privacy and logging stay strict
Privacy manifest enforced. Gateway logs metadata only. Exit: no request/response body logging.

## Phase 10 — Cross-plane acceptance proof
Single probe covers Conduit ready (already true), Resonance ready (stamped), and real device archive evidence. Exit: production verdict accepted. Fixture or classifier test is insufficient.

Binding constraints: Resonance owner secret + CHR-55 device archive. Neither is closed by simulator or classifier. High open-PR entropy remains the current operational risk and must be pruned first.

## Innovation Track (advanced — no gates violated)
1. Pure PortfolioPosture classifier holds. Fail-closed. Maturity score added to probe.
2. portfolio-probe tools with cold-start backoff (retry on 503) — landed.
3. Open PR entropy reporting added to probe (Conduit #282, CI green) for quantitative hygiene tracking.
4. Hygiene prune priority: close superseded docs-only PRs; use merge-train where available; merge only CI-green non-overlapping hardens.
5. Adversarial review of recent hardens continues.
6. Cross-plane readiness contract v1 alignment across repos.
7. Lockfile / Dependabot residual hygiene.
8. Cross-repo consistency: this evidence block is canonical; mirror key notes.
9. Chamber and capability plane advances held pending no-gate confirmation.
10. On-device diagnostics post Phase 8 only. Fresh probe confirms identical fail-closed posture. No regression.

Highest-value next: aggressively reduce open PR entropy (close docs-only superseded first, merge green non-overlapping hardens like #282 after review), then owner gates (SUPABASE key + CHR-55 IPA). Stabilization holds. Innovate continues under constraints.
