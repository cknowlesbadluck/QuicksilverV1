# Portfolio 10-phase roadmap — 2026-10-03 15:00 EDT

Live probes at 2026-10-03T19:01:37Z. No secrets invented. Refreshed in place on #218. No new roadmap PR.

Evidence:
- Resonance `GET /api/ready` returned 503 at `2026-10-03T19:01:37.226Z`. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. Body omitted `ownerActionRequired` and `contractRevision`. `/api/health` was 200. Owner gate plus deploy lag.
- Conduit `GET /health` and `GET /ready` both returned 200 `version=0.8.0` `contractRevision=2026-10-03-ready-surface` ready `persistence=postgres`.
- QuicksilverV1 main is `9b08845e` after #217 (M3-T4 routing config). This PR may be behind main. #209 UI smoke failed. CHR-55 device HG is unobservable here. Simulator CI is not that gate.

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
