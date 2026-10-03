# Portfolio 10-phase roadmap — 2026-10-03 18:03 EDT

Live probes at 2026-10-03T22:03:28Z. No secrets invented. A classifier is not production proof. A Vercel alias is not the public gate.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. Body omitted `ownerActionRequired` and `contractRevision`. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. Auth mode required and ok. Persistence and GitHub adapter not configured. `/api/health` returned 200.
- GitHub production deployment success against a Vercel alias is not this gate. `classifyResonanceReady` now returns `wrong_host` for that alias and `owner_blocked` for this public 503. That classifier is on Conduit `#174`, not merged, and is not proof.
- Conduit `GET /health` and `GET /ready` both returned 200 with `version=0.8.0` and `contractRevision=2026-10-03-ready-surface`. Ready persistence is postgres. Diagnostics ok. Bound agent `grok`, no binding conflict. `activity_prune` removed 0.
- QuicksilverV1 `#218` is this refresh. `#209` (checkout 4 to 7) is open and UI smoke failed on contrast in `SanctumSmokeTests`. Do not merge it. Device HG remains the product gate.
- Legacy `cknowlesbadluck/Quicksilver` has no open issues visible to this token. Do not merge Conduit `#119`, `#120`, `#155`.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Kill the split-brain deploy

Public Netlify still omits `contractRevision`. Exit: public ready body contains `contractRevision` equal to `2026-10-03-owner-gate`, and no alias host is accepted as proof.

## Phase 3 — Conduit contract parity

Met on the live host at 22:03Z. Exit already held: `/health` and `/ready` share version 0.8.0 and `2026-10-03-ready-surface`. Do not reopen this as an outage.

## Phase 4 — Quicksilver smoke

`#209` stays open while UI smoke is red. Exit: contrast audit green, or the bump is closed. Device HG still open.

## Phase 5 — Persistence proof

After Phase 1, run production smoke against the real 200 body on `resonancenexus`. Exit: smoke passes on that host, not on a Vercel alias.

## Phase 6 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free.

## Phase 7 — Hygiene prune

No hourly audit files. One roadmap file, refreshed in place. Do not merge red drafts. Open feature/harden count is over the entropy cap; next code change replaces a pull request, it does not add one.

## Phase 8 — One iOS target

`#134` is diverged from current main. Do not start a second client. Exit: `#134` builds on current main, or it is closed.

## Phase 9 — Grants stay deny-by-default

Conduit resource records hold no secrets. Exit: grant tests green.

## Phase 10 — Cross-plane acceptance

One probe covers Conduit ready, public Resonance ready, and Quicksilver posture. Exit: all three green on their public hosts. A unit test is not that proof.

Binding constraint: owner secret on Netlify, plus a deploy that actually reaches that host. Agent work cannot close Phase 1.
