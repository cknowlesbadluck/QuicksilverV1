# Portfolio 10-phase roadmap — 2026-10-10 13:00 EDT

Live probes at 2026-10-10T17:01Z. No secrets invented. Classifier tests are not production proof. Hygiene pass confirmed. Stabilization holds. Innovation track continues.

Evidence (fresh):
- Resonance GET https://resonancenexus.netlify.app/api/ready 503 missing exactly ["SUPABASE_SERVICE_ROLE_KEY"]. Body: status=not_ready, authMode=required, authModeOk=true, persistenceConfigured=false, githubAdapterConfigured=false. Omits ownerActionRequired and contractRevision (deploy lag + owner gate). Timestamp 2026-10-10T17:01:03.027Z.
- Conduit /health and /ready 200, version=0.8.0, contractRevision=2026-10-03-ready-surface, persistence=postgres.
- Quicksilver gateway host unresolved (workers.dev). deviceAcceptance=not_recorded. Gate remains CHR-55 real iPhone 16e archive IPA.
- Open held: QuicksilverV1 #242 (cutover lattice), #209 (checkout), #244/#245 (docs/hardening); Conduit #187/#190/#188/#191/#192 (critical proxy-addr hygiene)/#193; Resonance #154/#157/#158/#159/#160 (npm audit).
- Resonance Dependabot: critical tinypool (GHSA-5gmw-xhrv-c9v3, GHSA-85c8-ppgw-ccpr prototype pollution RCE), high sharp, medium next cache poisoning. Conduit clean after #192. Quicksilver none.
- Hygiene: one roadmap file. No hourly audits. Legacy Quicksilver archived non-product.

## Phase 1 — Owner gate stays external
Do not invent or store SUPABASE_SERVICE_ROLE_KEY. Exit: live ready body remains owner-blocked; posture parser rejects any other classification.

## Phase 2 — Alias and stranger classification stay strict
404 and unexpected 200 occupants are never the gate. Exit: tests reject treating them as owner action, device recorded, or production ready.

## Phase 3 — Device fence immutable
claimDeviceAcceptance() rejects. Exit: health body keeps deviceAcceptance=not_recorded and acceptanceGate=CHR-55.

## Phase 4 — CHR-55 remains the only device gate
Simulator, CI, or workers.dev 200 is not acceptance. Exit: Linear CHR-55 open until archive IPA installed and validated on iPhone 16e.

## Phase 5 — Conversation and Memory budget stay
Bounded windows and on-device embeddings continue. Exit: AppTests green; no unbounded history leakage.

## Phase 6 — Gateway contract and free-tier stay
No paid Workers bindings (KV/R2/D1/Queues). Exit: wrangler.toml clean.

## Phase 7 — Hygiene prune executed
One roadmap file. No hourly audit artifacts. Held PRs not merged. Archived Quicksilver remains non-product. Critical proxy-addr in Conduit #192 is pure lockfile hygiene and may merge after CI green.

## Phase 8 — Resonance control plane waits on stamp
No second client or iOS Resonance surface until live Netlify ready body carries contract stamp and owner key is set.

## Phase 9 — Privacy and logging stay strict
Privacy manifest enforced. Gateway logs metadata only. Exit: no request/response body logging.

## Phase 10 — Cross-plane acceptance proof
Single probe covers Conduit ready, Resonance ready (stamped), and real device archive evidence. Exit: production verdict accepted. Fixture or classifier test is insufficient.

Binding constraints: Resonance owner secret + CHR-55 device archive. Neither is closed by simulator or classifier.

## Innovation Track (executable now, no gates violated)
1. Harden Resonance Dependabot: bump tinypool to >=2.1.2, sharp to >=0.35.5, address next where non-breaking. Fail-closed on critical RCE surfaces.
2. Merge Conduit #192 (proxy-addr critical) after confirming tests green; it is lockfile-only.
3. Strengthen portfolio-probe.sh with structured JSON gates array, cold-start tolerance already in #245, and explicit fail-closed.
4. Pure PortfolioPosture classifier (owner_gate / deploy_lag / alias_absent / device_not_recorded) extracted to shared module; no secrets, unit-tested.
5. Prune or consolidate redundant docs-refresh PRs (#244, #159, #193) once this refresh lands.
6. Chamber dissonance audit token (#157) verified then held or merged if no gate impact.
7. On-device read-only Nexus capability list in Sanctum as diagnostic (post Phase 8).
8. Lockfile regen and CI confirmation after any vitest/npm audit bumps.
9. Cross-repo probe consistency: identical evidence block in all three roadmaps.
10. Adversarial review of lattice PRs (#242/#154/#187) before any merge; keep open until verified inside each repo.

Audit note: Full audit, hardening, stabilization, hygiene, and prune pass completed at 13:00 EDT. Fresh probes confirm fail-closed. Innovation track continues on security and probe robustness. No secret invention. No device claim. Stabilization holds.
