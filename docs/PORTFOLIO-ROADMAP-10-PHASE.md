# Portfolio 10-phase roadmap — 2026-10-09 08:02 EDT

Live probes at 2026-10-09T12:02:13Z. No secrets invented. A classifier test is not production proof. This pass did not merge #242.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. Body missing exactly `SUPABASE_SERVICE_ROLE_KEY`. `ownerActionRequired` and `contractRevision` omitted on the host. Source on Resonance main already stamps both. Deploy lag plus owner gate.
- `https://resonanceplane.vercel.app/api/ready` returned 404 `DEPLOYMENT_NOT_FOUND`. Alias absent. `PortfolioPosture.aliasAbsent` must not treat that as an owner gate.
- Conduit health and ready returned 200, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`.
- QuicksilverV1 gateway health is liveness only. `deviceAcceptance` stays `not_recorded`. Acceptance gate is CHR-55, an iPhone 16e archive IPA. `mercury-gateway.cknowlesbadluck.workers.dev` did not resolve in this pass.
- Held: #242 says do not merge. #209 is the dependabot checkout bump.

## Phase 1 — Owner gate is not this repo
Do not invent `SUPABASE_SERVICE_ROLE_KEY`. Exit: posture parse of the live 503 stays owner-blocked.

## Phase 2 — Alias absent is not the gate
Vercel 404 is `aliasAbsent`. Exit: `PortfolioPostureTests` rejects treating it as owner action or device acceptance.

## Phase 3 — Device fence stay
`claimDeviceAcceptance()` always rejects. Exit: health body keeps `deviceAcceptance=not_recorded` and `acceptanceGate=CHR-55`.

## Phase 4 — CHR-55 remains the device gate
Simulator CI and a workers.dev 200 are not acceptance. Exit: Linear CHR-55 stays open until an archive IPA is on the iPhone 16e.

## Phase 5 — Conversation budget stay
Brain still sends a bounded prior-turn window. Exit: AppTests green on the recording provider. Device HG still open.

## Phase 6 — Gateway contract stay
Do not add paid Workers bindings. Exit: `wrangler.toml` still has no KV, R2, D1, or Queues.

## Phase 7 — Hygiene prune
No hourly audit files. One roadmap file. Do not merge #242 in this pass. Archived `cknowlesbadluck/Quicksilver` is not the product.

## Phase 8 — Resonance cockpit waits
No second client. iOS Resonance work waits until the Netlify ready body carries the contract stamp.

## Phase 9 — Privacy stay
Privacy manifest and metadata-only gateway logs stay. Exit: no request or response body logging in the gateway.

## Phase 10 — Cross-plane acceptance
One probe covers Conduit ready, Resonance ready, and a real device archive. Exit: production verdict accepted. A fixture test is not that proof.

Binding constraint: CHR-55 device archive, and the Resonance owner secret. Neither is closed by a simulator job.
