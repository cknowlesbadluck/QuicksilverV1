# Portfolio 10-phase roadmap — 2026-10-08 07:00 EDT

Live probes at 2026-10-08T11:01:18Z. No secrets invented. Refreshed in place on `harden/entropy-governor-2300`. No new witness pull.

Evidence:
- Conduit `/health` and `/ready` 200, version 0.8.0, contract `2026-10-03-ready-surface`, persistence postgres.
- Resonance public `/api/ready` 503, missing exactly `SUPABASE_SERVICE_ROLE_KEY`. Body omitted `ownerActionRequired` and `contractRevision`.
- `resonancenexus.vercel.app` 404 `DEPLOYMENT_NOT_FOUND`, classified `alias_absent`.
- Open QuicksilverV1 pulls: #209 dependabot, #238 degrade planner, #240 entropy governor, #241 device acceptance. Simulator CI is not CHR-55.
- Legacy `cknowlesbadluck/Quicksilver` archive is owner-only on 403.

## Phase 1 — Owner gate
Netlify `SUPABASE_SERVICE_ROLE_KEY` on `resonancenexus` only. Not an iOS change.

## Phase 2 — Deploy-lag kill
Alias absence is not a gateway defect.

## Phase 3 — Entropy governor
Witness budget is 2. Exit: #240 tests green. No new status pull.

## Phase 4 — Collapse planners
#238 stays unmerged until checks are green. Dependabot #209 is not a product slice.

## Phase 5 — Device fence
Exit: recorded hardware run on iPhone 16e. Simulator green does not close this phase.

## Phase 6 — Gateway fail-closed
Unhealthy gateway health refuses device acceptance. Exit: #241 tests green, not deployed by this pass.

## Phase 7 — Hygiene prune
No hourly audit files. One roadmap file.

## Phase 8 — Single iOS target
QuicksilverV1 is the only client. Do not revive `cknowlesbadluck/Quicksilver`.

## Phase 9 — No secret in gateway config
Do not commit tokens. Exit: config stays free of service-role material.

## Phase 10 — Cross-plane acceptance
Exit: Conduit ready, Resonance ready 200, and a device archive. Unit tests are not that proof.

Binding constraint: owner secret, then device HG. Agent work cannot close Phase 1 or Phase 5.
