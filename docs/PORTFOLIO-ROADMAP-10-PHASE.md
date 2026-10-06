# Portfolio 10-phase roadmap — 2026-10-06 19:00 EDT

Live probes at 2026-10-06T23:01:40Z. No secrets invented. A classifier is not production proof.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned **503**. Body still omits `ownerActionRequired` and `contractRevision`. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. Auth mode required and ok. Persistence and GitHub adapter not configured.
- Source on main already emits those fields (`src/deploy/health.ts`). The public host is deploy-lagged. `#150` is the contract-pin PR. Do not open a third ready-body change.
- Conduit `GET /health` and `GET /ready` both returned 200, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, persistence postgres. Diagnostics ok. Bound agent `grok`, no binding conflict.
- QuicksilverV1 main is `182d1334`. Open: `#238` degrade planner, `#209` dependabot checkout 4 to 7. CHR-55 device HG on iPhone 16e remains the product gate. Simulator CI is not that gate.
- Legacy `cknowlesbadluck/Quicksilver` is not the product. Its open PRs were closed this pass as superseded. Archiving the repo still needs an owner token; this pass cannot archive it.
- `cknowlesbadluck/mcp` is already archived.
- Entropy at probe time: Resonance 5 open, Conduit 8 open, QuicksilverV1 2 open. Keep red: Conduit `#119` `#120`. Do not merge `#155` `#162` until the Render TLS env is set.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Kill the split-brain deploy

`#150` stays the only ready-body pin. Exit: public Netlify body contains `contractRevision` and `ownerActionRequired`. A green Vercel alias does not close this phase.

## Phase 3 — Admission gate

Ship the project-agnostic `work_admission` classifier on Conduit. Exit: unit tests green; the tool does not mutate records and does not accept secrets. Live host still on 0.8.0 until this merges and deploys.

## Phase 4 — Entropy prune

Close stale pre-October Resonance counsel PRs and Bolt micro-opts. Keep red drafts and secret-blocked TLS PRs stay open. Exit: open PR count drops, and no keep-red PR is closed.

## Phase 5 — Quicksilver device gate

Do not treat simulator CI as release. Exit: CHR-55 archive IPA installed on iPhone 16e, or an explicit owner waiver. `#209` rebases only after checkout 7 is proven on the iOS job.

## Phase 6 — One degrade planner

`#151` / `#182` / `#238` are the same invariant. Merge one after CI, close the duplicates. Exit: one degrade-planner implementation on each default branch, not three drifting copies.

## Phase 7 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free on Resonance main.

## Phase 8 — One iOS target

Do not start a second Resonance client. `#134` was closed this pass as diverged from current main. Exit: a single app target rebuilt on current main, or no iOS app PR.

## Phase 9 — Grants stay deny-by-default

Conduit resource records hold no secrets. TLS verify stays unmerged until Render env is set. Exit: grant tests green; `#155` and `#162` still closed-to-merge.

## Phase 10 — Cross-plane acceptance

One probe covers Conduit ready, public Resonance ready, and Quicksilver device posture. Exit: all three green on their real hosts. A unit test is not that proof.

Binding constraint: owner secret on Netlify, plus a deploy that actually reaches that host. Agent work cannot close Phase 1.
