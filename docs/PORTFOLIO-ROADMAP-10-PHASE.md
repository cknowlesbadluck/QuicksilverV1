# Portfolio 10-phase roadmap — 2026-10-03 13:00 EDT

Live probes at 2026-10-03T17:01:31Z. No secrets invented. A classifier test is not production proof.

Evidence:
- Conduit `GET /health` and `GET /ready` both returned 200 with `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`. Surface split from the 07:00 roadmap is closed on the live host.
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. `missingRequired` is exactly `["SUPABASE_SERVICE_ROLE_KEY"]`. Body omitted `ownerActionRequired` and `contractRevision`. Owner gate plus deploy lag. GitHub production deployment status is not this gate.
- QuicksilverV1 main is `5eb30beb`. #215 is on main. #217 (M3-T4 routing) and #218 (roadmap) are open. #209 stays unmerged while UI smoke is red. CHR-55 device HG on iPhone 16e is still the product gate. Simulator CI is not that gate.
- Activity prune removed 0 rows. Legacy `cknowlesbadluck/Quicksilver` is still unarchived.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Deploy-lag kill on the public host

#147 is merged at `a9331e6b`. #148 is open and must not be treated as proof until it is on the public host. Exit: production ready body contains the current `contractRevision`.

## Phase 3 — Conduit contract parity

Met on the live host at 13:00 EDT. Keep #119, #120, #155, and #162 unmerged. Exit already met: `/health` and `/ready` share version 0.8.0 and `2026-10-03-ready-surface`.

## Phase 4 — Quicksilver device HG

#217 is not device acceptance. Exit: CHR-55 archive IPA runs on iPhone 16e. Do not call simulator green a ship.

## Phase 5 — Persistence proof

After Phase 1, run production smoke against the real 200 body. Exit: smoke passes on `resonancenexus`, not a preview.

## Phase 6 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free.

## Phase 7 — Hygiene prune

One roadmap file per repo. Delete orphan branches with no open PR. Do not merge red required CI. Archive legacy `cknowlesbadluck/Quicksilver` from the owner account; agent archive calls return 403.

## Phase 8 — One iOS client

Resonance #134 stays open until it builds or is closed. Do not start a second cockpit. Exit: one iOS target, not two.

## Phase 9 — Grant and bridge audit

Conduit grants stay deny-by-default. Exit: grant tests green and no resource record holds a secret.

## Phase 10 — Cross-plane acceptance

`classifyPortfolioGate` in Conduit classifies probes. It does not fetch them. Exit: live Conduit ready, live Resonance ready, and Quicksilver device HG all green. The unit test is not that proof.

Binding constraint: owner secret on Netlify, and owner device HG. Agent work cannot close Phase 1 or Phase 4.
