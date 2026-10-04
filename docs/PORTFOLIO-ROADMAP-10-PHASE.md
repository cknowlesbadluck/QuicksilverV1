# Portfolio 10-phase roadmap — 2026-10-04 02:01 EDT

Live probes at 2026-10-04T06:01:31Z. No secrets invented.

Evidence:
- Resonance `GET /api/ready` returned 503. Body omitted `ownerActionRequired` and `contractRevision`. Missing key is exactly `SUPABASE_SERVICE_ROLE_KEY`. Netlify deploy `6ac1ec169978e382dae16891` skipped: account credit usage exceeded.
- Conduit `GET /health` and `GET /ready` both returned 200 with `version=0.8.0` and `contractRevision=2026-10-03-ready-surface`. Persistence is postgres.
- QuicksilverV1 main is `db1acb46` (#221, M3-T8). M3-T9 was 1 ahead and 0 behind; opened as #222. `harden/history-budget` is a separate 1-commit branch. Simulator CI is not CHR-55.

## Phase 1 — Owner secret

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Netlify credit, then contract on the host

Restore credit and republish Resonance main. Exit: production ready body contains the current `contractRevision`.

## Phase 3 — Conduit stamp parity

Met on the host. Exit already holds: `/health` and `/ready` share one contract revision.

## Phase 4 — Quicksilver history slice

Land #222 only if required CI and UI smoke are green. Do not also merge `harden/history-budget` without a diff. Exit: M3-T9 on main. Device HG remains open.

## Phase 5 — Persistence proof

After Phase 1 and Phase 2, run production smoke against the real 200 body. Exit: smoke passes on `resonancenexus`, not a preview.

## Phase 6 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free.

## Phase 7 — Hygiene prune

No hourly audit files. One roadmap file per repo. Do not merge Conduit #119, #120, or #155. Archive `cknowlesbadluck/Quicksilver` when the token allows it.

## Phase 8 — iOS cockpit only after the app target is green

Do not start a second client. Resonance #134 stays open until it builds or is closed. Exit: one iOS target, not two.

## Phase 9 — Grant and bridge audit

Conduit grants stay deny-by-default. Exit: grant tests green and no resource record holds a secret.

## Phase 10 — Cross-plane acceptance

One probe covers Conduit ready, Resonance ready, and Quicksilver device HG. Exit: all three green on production. A classifier unit test is not that proof.

Binding constraint: owner secret plus Netlify credits. Agent work cannot close Phase 1 or Phase 2.
