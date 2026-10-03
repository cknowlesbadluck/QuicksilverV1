# Portfolio 10-phase roadmap — 2026-10-03 14:00 EDT

Live probes at 2026-10-03T18:00:51Z (Conduit) and 2026-10-03T18:00:54.156Z (Resonance). No secrets invented. A classifier test is not production proof. An open roadmap pull request is not production proof.

Evidence:
- Conduit `GET /health` and `GET /ready` both returned 200 with `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`. Diagnostics ok. `boundAgentId=grok`, `bindingConflict=false`.
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. `missingRequired` is exactly `["SUPABASE_SERVICE_ROLE_KEY"]`. Body omitted `ownerActionRequired` and `contractRevision`. Owner gate plus deploy lag.
- This PR base is `5eb30beb`. Branch list at audit showed main `9b08845e`, so this roadmap branch may be behind. #209 UI smoke failed and stays unmerged. CHR-55 device HG on iPhone 16e is unobservable from this host. Simulator CI is not that gate.
- Conduit #172 carries `splitPortfolioActions` and is not merged. #218 is this in-place roadmap PR. Do not open another.
- `activity_prune` removed 0. Legacy `cknowlesbadluck/Quicksilver` is still unarchived. `cknowlesbadluck/mcp` is already archived.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Deploy-lag kill on the public host

#147 is merged at `a9331e6b`. The public body still omits `contractRevision`. Exit: production ready body contains the current `contractRevision`.

## Phase 3 — Conduit contract parity

Met on the live host at 14:00 EDT. Keep #119, #120, #155, and #162 unmerged. Exit already met: `/health` and `/ready` share version 0.8.0 and `2026-10-03-ready-surface`.

## Phase 4 — Quicksilver device HG

Simulator green is not device acceptance. Exit: CHR-55 archive IPA runs on iPhone 16e. This host cannot close the phase.

## Phase 5 — Persistence proof

After Phase 1, run production smoke against the real 200 body. Exit: smoke passes on `resonancenexus`, not a preview.

## Phase 6 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free.

## Phase 7 — Hygiene prune

One roadmap file per repo. Refresh it in place. Do not open a second roadmap PR. Do not merge red required CI. Archive legacy `cknowlesbadluck/Quicksilver` from the owner account; agent archive calls return 403.

## Phase 8 — One iOS client

Resonance #134 stays open until it builds or is closed. Do not start a second cockpit. Exit: one iOS target, not two.

## Phase 9 — Grant and bridge audit

Conduit grants stay deny-by-default. Exit: grant tests green and no resource record holds a secret.

## Phase 10 — Cross-plane acceptance

`classifyPortfolioGate` classifies probes. `splitPortfolioActions` classifies owner work, agent work, and non-proof. Neither fetches. Exit: live Conduit ready, live Resonance ready, and Quicksilver device HG all green. The unit test is not that proof.

Binding constraint: owner secret on Netlify, owner archive of the legacy repo, and owner device HG. Agent work cannot close Phase 1, Phase 4, or the archive.
