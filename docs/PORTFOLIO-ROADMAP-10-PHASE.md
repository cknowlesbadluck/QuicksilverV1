# Portfolio 10-phase roadmap — 2026-10-03 07:00 EDT

Live probes at 2026-10-03T11:01:43Z. No secrets invented.

Evidence:
- Resonance `GET /api/ready` returned 503. Body: `status=not_ready`, `missingRequired=[SUPABASE_SERVICE_ROLE_KEY]`, `authMode=required`, `authModeOk=true`, `persistenceConfigured=false`, `githubAdapterConfigured=false`. Body omitted `ownerActionRequired` and `contractRevision`. Owner gate, plus deploy lag.
- Conduit `GET /health` returned 200 `{"status":"ok","service":"conduit"}` with no version. `GET /ready` returned 200 `version=0.8.0` `persistence=postgres`. Contract split, not an outage.
- QuicksilverV1 #215 squash-merged at 9663f627. `PortfolioPosture.deployLag` is on main. Simulator CI is not device acceptance. CHR-55 remains open.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Deploy lag kill

Land Resonance #147 only after CodeRabbit is cleared. Exit: production ready body contains the current `contractRevision`.

## Phase 3 — Conduit header and health parity

Land one health contract, not three. #170 is the candidate; Workers Builds failed, so it stays unmerged. Exit: live `/health` and `/ready` both return version 0.8.0.

## Phase 4 — Quicksilver fail-closed posture

Done on main via #215. Exit already met: stale 503 is deploy lag; stamped 503 is owner-blocked; malformed JSON is fail-closed. Device HG is still open.

## Phase 5 — Persistence proof

After Phase 1, run production smoke against the real 200 body. Exit: smoke passes on `resonancenexus`, not a preview.

## Phase 6 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free.

## Phase 7 — Hygiene prune

No hourly audit files. One roadmap file per repo. Do not merge #119, #120, or #155. Close or rebase overlapping Conduit bolt PRs before adding scope.

## Phase 8 — iOS cockpit only after the app target is green

Do not start a second client. Resonance #134 stays open until it builds or is closed. Exit: one iOS target, not two.

## Phase 9 — Grant and bridge audit

Conduit grants stay deny-by-default. Exit: grant tests green and no resource record holds a secret.

## Phase 10 — Cross-plane acceptance

One probe covers Conduit ready, Resonance ready, and Quicksilver posture parse. Exit: all three green on production. A classifier unit test is not that proof.

Binding constraint: owner secret on Netlify. Agent work cannot close Phase 1.
