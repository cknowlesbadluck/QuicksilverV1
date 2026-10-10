# Portfolio 10-phase roadmap — 2026-10-09 20:00 EDT

Live probes at ~2026-10-10T00:00Z. No secrets invented. Classifier tests are not production proof. This pass did not merge #242 or #209.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` still 503 missing exactly `SUPABASE_SERVICE_ROLE_KEY`. Body omits `ownerActionRequired` and `contractRevision` on the live host (source stamps them; deploy lag + owner gate).
- Vercel aliases return 404 `DEPLOYMENT_NOT_FOUND` or stranger occupants. Classify as `aliasAbsent` or `stranger_occupant`; never as owner gate or device acceptance.
- Conduit `/health` and `/ready` 200, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, `persistence=postgres`. Diagnostics scopeParity ok.
- QuicksilverV1 gateway remains liveness-only. `deviceAcceptance=not_recorded`. Gate is CHR-55 real iPhone 16e archive IPA.
- Open held: QuicksilverV1 #242 (cutover lattice), #209 (checkout bump); Conduit #187/#190/#188/#162/#155/#120; Resonance #154/#157. Dependabot medium vitest path-traversal on Resonance (dev-server only).
- Supabase projects for Resonance/Quicksilver reported INACTIVE in prior probes.

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
One roadmap file. No hourly audit artifacts. Held PRs not merged. Archived `Quicksilver` remains non-product. Dependabot vitest noted (medium, dev-only).

## Phase 8 — Resonance control plane waits on stamp
No second client or iOS Resonance surface until live Netlify ready body carries contract stamp and owner key is set.

## Phase 9 — Privacy and logging stay strict
Privacy manifest enforced. Gateway logs metadata only. Exit: no request/response body logging.

## Phase 10 — Cross-plane acceptance proof
Single probe covers Conduit ready, Resonance ready (stamped), and real device archive evidence. Exit: production verdict accepted. Fixture or classifier test is insufficient.

Binding constraints: Resonance owner secret + CHR-55 device archive. Neither is closed by simulator or classifier.

Innovation notes (this pass):
- Strengthen PortfolioPosture classifier with stranger_occupant and inactive Supabase signals.
- Add optional HMAC cursor secret path in Conduit once env is ready (see #162).
- Device-side validation script for CHR-55 that records acceptance only after real IPA install + health check.
- Chamber dissolve audit token hardening already in #157; land after owner gate clears.
