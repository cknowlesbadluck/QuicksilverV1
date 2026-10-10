# Portfolio 10-phase roadmap — 2026-10-10 03:01 EDT

Live probes at 2026-10-10T07:01Z. No secrets invented. Classifier tests are not production proof. This pass confirmed live state, refreshed evidence, and did not merge held PRs.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` 503 missing exactly `["SUPABASE_SERVICE_ROLE_KEY"]`. Body: status=not_ready, authMode=required, authModeOk=true, persistenceConfigured=false, githubAdapterConfigured=false. Omits `ownerActionRequired` and `contractRevision` (deploy lag + owner gate). Health 200 with stage=deployment.
- Conduit `/health` and `/ready` 200, version=0.8.0, contractRevision=2026-10-03-ready-surface, persistence=postgres. Diagnostics scopeParity present.
- Quicksilver gateway host unresolved (workers.dev). deviceAcceptance=not_recorded. Gate remains CHR-55 real iPhone 16e archive IPA.
- Open held: QuicksilverV1 #242 (cutover lattice), #209 (checkout bump); Conduit #187/#190/#188/#162/#155/#119/#120 (drafts red); Resonance #154/#157.
- Hygiene: one roadmap file. No hourly audits. Legacy Quicksilver archived non-product. Dependabot residuals noted on Resonance (vitest/postcss).

## Phase 1 — Owner gate stays external
Do not invent or store `SUPABASE_SERVICE_ROLE_KEY`. Exit: live ready body remains owner-blocked; posture parser rejects any other classification.

## Phase 2 — Alias and stranger classification stay strict
404 and unexpected 200 occupants are never the gate. Exit: tests reject treating them as owner action, device recorded, or production ready.

## Phase 3 — Device fence immutable
`claimDeviceAcceptance()` rejects. Exit: health body keeps `deviceAcceptance=not_recorded` and `acceptanceGate=CHR-55`.

## Phase 4 — CHR-55 remains the only device gate
Simulator, CI, or workers.dev 200 is not acceptance. Exit: Linear CHR-55 open until archive IPA installed and validated on iPhone 16e.

## Phase 5 — Conversation and Memory budget stay
Bounded windows and on-device embeddings continue. Exit: AppTests green; no unbounded history leakage.

## Phase 6 — Gateway contract and free-tier stay
No paid Workers bindings (KV/R2/D1/Queues). Exit: `wrangler.toml` clean.

## Phase 7 — Hygiene prune executed
One roadmap file. No hourly audit artifacts. Held PRs not merged. Archived `Quicksilver` remains non-product.

## Phase 8 — Resonance control plane waits on stamp
No second client or iOS Resonance surface until live Netlify ready body carries contract stamp and owner key is set.

## Phase 9 — Privacy and logging stay strict
Privacy manifest enforced. Gateway logs metadata only. Exit: no request/response body logging.

## Phase 10 — Cross-plane acceptance proof
Single probe covers Conduit ready, Resonance ready (stamped), and real device archive evidence. Exit: production verdict accepted. Fixture or classifier test is insufficient.

Binding constraints: Resonance owner secret + CHR-55 device archive. Neither is closed by simulator or classifier.

Innovation notes (this pass):
- Fresh live probes locked: Resonance ready 503 exact missing key, health 200; Conduit fully stamped ready + diagnostics.
- portfolio-probe.sh already supports --json; next: add explicit owner_gate / deploy_lag / alias_absent classification in structured output without claiming proof.
- Strengthen held PortfolioPosture classifiers with inactive Supabase and stranger_occupant signals.
- Optional HMAC cursor path in Conduit remains gated on env (#162).
- Device-side CHR-55 validation remains owner-only after real IPA install.
- Cross-plane probe remains the fail-closed gate before claiming Phase 10.
