# Portfolio 10-phase roadmap — 2026-10-03 21:01 EDT

Live probes at 2026-10-04T01:01:23Z. No secrets invented. A classifier is not production proof. A Vercel alias, including a 302 into SSO, is not the public gate.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. Body omitted `ownerActionRequired` and `contractRevision`. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. Auth mode required and ok. Persistence and GitHub adapter not configured.
- `GET https://resonance-2in3qv6ni-inbetweenz.vercel.app/api/ready` returned 302 to `vercel.com/sso-api` with body `Protected by Vercel Authentication`. That is an alias challenge, not a deploy success.
- Conduit `GET /health` and `GET /ready` both returned 200 with `version=0.8.0` and `contractRevision=2026-10-03-ready-surface`. Ready persistence is postgres. Bound agent `grok`, no binding conflict.
- QuicksilverV1 open work is `#218` (this roadmap refresh) and `#209` (checkout 4 to 7). Device HG remains the product gate. Do not treat simulator CI as that gate.
- Legacy `cknowlesbadluck/Quicksilver` pulls `#1` and `#2` are the dead twin. Close them. Do not merge Conduit `#119`, `#120`, `#155`.
- Open feature/harden count on Conduit is over the entropy cap. This refresh updates `#218` and Conduit `#174`. It does not open a new pull request.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Kill the split-brain deploy

Public Netlify still omits `contractRevision`. The Vercel alias is SSO-walled. Exit: public ready body contains `contractRevision` equal to `2026-10-03-owner-gate`, and a 302 SSO response cannot be classified as proof.

## Phase 3 — Conduit contract parity

Met on the live host at 01:01Z. Exit already held: `/health` and `/ready` share version 0.8.0 and `2026-10-03-ready-surface`. Do not reopen this as an outage.

## Phase 4 — Quicksilver smoke and device gate

`#209` stays open while UI smoke is red. Exit: contrast audit green, or the bump is closed. Device HG on iPhone 16e still open. Simulator green is not CHR-55.

## Phase 5 — Persistence proof

After Phase 1, run production smoke against the real 200 body on `resonancenexus`. Exit: smoke passes on that host, not on a Vercel alias.

## Phase 6 — Chamber fail-closed stays

No new provider. Execution stays denied when a capability is not executable. Exit: chamber tests stay red-free.

## Phase 7 — Hygiene prune

No hourly audit files. One roadmap file, refreshed in place. Close the legacy twin pulls. Do not merge red drafts. Next code change replaces an open pull request; it does not add one.

## Phase 8 — One iOS target

Resonance `#134` is diverged from current main. Do not start a second Resonance client inside Quicksilver. Exit: one native target, device HG recorded.

## Phase 9 — Grants stay deny-by-default

Conduit resource records hold no secrets. `#155` stays unmerged until Render TLS env is set. Exit: grant tests green and TLS verify is on without breaking ready.

## Phase 10 — Cross-plane acceptance

One probe covers Conduit ready, public Resonance ready, and Quicksilver device posture. Exit: all three green on their real hosts. A unit test is not that proof.

Binding constraint: owner secret on Netlify, plus a deploy that actually reaches that host. Agent work cannot close Phase 1. Quicksilver device HG cannot close it either.
