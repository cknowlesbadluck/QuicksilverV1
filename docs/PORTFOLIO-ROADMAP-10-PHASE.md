# Portfolio 10-phase roadmap — 2026-10-03 16:00 EDT

Live probes at 2026-10-03T20:01:23Z. No secrets invented. A classifier unit test is not production proof.

Evidence:
- Resonance `GET /api/ready` returned 503. Body: `status=not_ready`, `missingRequired=[SUPABASE_SERVICE_ROLE_KEY]`, `authMode=required`, `authModeOk=true`, `persistenceConfigured=false`, `githubAdapterConfigured=false`. Body omitted `ownerActionRequired` and `contractRevision`.
- Resonance `GET /api/health` returned 200.
- Conduit `GET /health` and `GET /ready` both returned 200, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`. Phase 3 exit is satisfied ahead. It does not unlock Phase 1.
- Conduit diagnostics: health, PRM, AS, JWKS, scope parity ok. `activity_prune` removed 0.
- QuicksilverV1 main `9b08845`. Open: #219 error classification, #218 this roadmap, #209 dependabot. Device HG is CHR-55. Simulator CI is not device acceptance.
- Do not merge #119, #120, #155, #162, #164, #168, #209. Legacy `cknowlesbadluck/Quicksilver` archive remains an owner action (prior integration close returned 403).

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: `GET /api/ready` is 200 and `missingRequired` is empty.

## Phase 2 — Deploy lag kill

Public ready body must carry the current `contractRevision`. A GitHub deployment on a Vercel alias is not this exit. Exit: production ready body contains the contract stamp and omits no required owner field.

## Phase 3 — Conduit header and health parity

Satisfied on the live host at 20:01Z. Both surfaces return version 0.8.0 and the same contract revision. Keep it; do not reopen a second health contract.

## Phase 4 — Quicksilver fail-closed posture

Posture parse is on main. Exit still open for product: CHR-55 device HG on iPhone 16e. Simulator green is not this exit.

## Phase 5 — Persistence proof

After Phase 1, run production smoke against the real 200 body. Exit: smoke passes on `resonancenexus`, not a preview.

## Phase 6 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free on main.

## Phase 7 — Hygiene prune

One roadmap file per repo. No hourly audit files. Open PR load is the debt: Conduit 7, Resonance 4, QuicksilverV1 3. Close or rebase overlaps before adding scope. Do not merge the kept-red drafts.

## Phase 8 — iOS cockpit only after the app target is green

Resonance #134 stays open until it builds or is closed. Do not start a second client. Exit: one iOS target, not two.

## Phase 9 — Grant and bridge audit

Conduit grants stay deny-by-default. Exit: grant tests green and no resource record holds a secret. #162 and #155 stay unmerged until Render TLS env is set.

## Phase 10 — Cross-plane acceptance

One live probe covers Conduit ready, Resonance ready, and Quicksilver device HG. Exit: all three green on production. `planPhases` recording a later exit as `satisfiedAhead` is not that proof.

Binding constraint: owner secret on Netlify. Agent work cannot close Phase 1.
