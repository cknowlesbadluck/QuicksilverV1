# Portfolio 10-phase roadmap — 2026-10-07 23:00 EDT

Live probes at 2026-10-08T03:01:23Z. No secrets invented. A classifier is not production proof. Witness budget is 2; this pass is an implementation, not another status dump.

Evidence:
- Conduit `GET /health` and `GET /ready` returned 200, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`.
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. `missingRequired` is exactly `["SUPABASE_SERVICE_ROLE_KEY"]`. Body omitted `ownerActionRequired` and `contractRevision`. `/api/health` was 200.
- `https://resonancenexus.vercel.app` returned 404 `DEPLOYMENT_NOT_FOUND`. Classified `alias_absent`, not an owner gate.
- `activity_prune` removed 0. Legacy `cknowlesbadluck/Quicksilver` archive remains an owner action when the API returns 403.
- Do not merge Conduit #119, #120, #155, or #162.

## Phase 1 — Owner gate
Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200 and the body still omits `ownerActionRequired`.

## Phase 2 — Deploy-lag kill
Ready body on the canonical host must grow `contractRevision` only after the owner key is set and a deploy is proven by a second probe. Exit: production ready body contains `contractRevision`. A Vercel alias 404 is not that proof.

## Phase 3 — Entropy governor
`entropy-governor` refuses a new witness PR when two witness pulls are already open, and refuses keep-red numbers. Exit: governor tests green on the implementation PR. Do not open a fourth roadmap-only PR.

## Phase 4 — Collapse unmerged planners
Conduit #180 / #182 / #183 and Resonance #150 / #151 and QuicksilverV1 #238 stay unmerged until required checks are green. Exit: one squash per repo, or an explicit close as superseded. No merge of red required CI.

## Phase 5 — Quicksilver device fence
Simulator CI is not device acceptance. Exit: a recorded hardware run on iPhone 16e. CHR-55 stays owner-gated.

## Phase 6 — Resonance chamber fail-closed
No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free on main.

## Phase 7 — Hygiene prune
Delete orphan branches with no open PR. One roadmap file per repo. Close superseded docs PRs. Archive legacy Quicksilver if the token allows; 403 is an owner action.

## Phase 8 — Single iOS peer
Do not start a second Resonance client. Exit: one iOS target that consumes the Nexus capability model, after Phase 1.

## Phase 9 — Grant and TLS stay deny-by-default
#162 and #155 stay unmerged until Render TLS env is set. Exit: grant tests green and no resource record holds a secret.

## Phase 10 — Cross-plane acceptance
One probe covers Conduit ready, Resonance ready 200, and a Quicksilver device archive. Exit: all three green on production. Unit tests are not that proof.

Binding constraint: owner secret on Netlify, then device HG. Agent work cannot close Phase 1.
