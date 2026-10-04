# Portfolio 10-phase roadmap — 2026-10-04 00:01 EDT

Live probes at 2026-10-04T04:01:15Z. No secrets invented. A classifier test is not production proof.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. Body: `status=not_ready`, `missingRequired=[SUPABASE_SERVICE_ROLE_KEY]`, `authMode=required`, `authModeOk=true`, `persistenceConfigured=false`, `githubAdapterConfigured=false`. Body omitted `ownerActionRequired` and `contractRevision`. Owner gate plus deploy lag. `/api/health` was 200.
- Conduit `GET /health` and `GET /ready` both returned 200, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`. Header parity on the live host is met. It is not a grant or TLS proof.
- QuicksilverV1 main is `db1acb4682224fe7d95deedf7c3b37551915a200` (#221 multi-turn gateway history). M3-T9 is the implementation in this pass. Simulator CI is not device acceptance. CHR-55 remains open.

## Phase 1 — Owner gate
Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Deploy lag kill
#147 is already on main (`a9331e6b`) and is not live proof. Exit: production ready body contains `contractRevision` and `ownerActionRequired`.

## Phase 3 — Conduit contract stay
Live health and ready already share version and contract revision. Do not open another health-stamp PR. Exit: the next probe still matches `2026-10-03-ready-surface` after any deploy.

## Phase 4 — Quicksilver conversation budget
M3-T9: Brain sends at most 8 prior turns and the broker estimate includes them. Exit: AppTests green on the recording provider. Device HG is still open.

## Phase 5 — Persistence proof
After Phase 1, run production smoke against the real 200 body. Exit: smoke passes on `resonancenexus`, not a Vercel alias.

## Phase 6 — Chamber fail-closed stays
No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free on main.

## Phase 7 — Hygiene prune
No hourly audit files. One roadmap file per repo. Do not merge #119, #120, or #155. Close superseded docs PRs instead of stacking them. Legacy `cknowlesbadluck/Quicksilver` is not the product; archive remains an owner action if the integration returns 403.

## Phase 8 — iOS cockpit only after the app target is green
Do not start a second client. Resonance #134 stays open until it builds or is closed. Exit: one iOS target, not two.

## Phase 9 — Grant and bridge audit
Conduit grants stay deny-by-default. #162 and #155 stay unmerged until Render TLS env is set. Exit: grant tests green and no resource record holds a secret.

## Phase 10 — Cross-plane acceptance
One probe covers Conduit ready, Resonance ready, and a Quicksilver device archive on iPhone 16e. Exit: all three green on production. Unit tests are not that proof.

Binding constraint: owner secret on Netlify, then device HG. Agent work cannot close Phase 1 or CHR-55.
