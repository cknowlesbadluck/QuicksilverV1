# Portfolio 10-phase roadmap — 2026-10-03 12:00 EDT

Live probes at 2026-10-03T16:02:31Z. No secrets invented.

Evidence:
- Resonance public `GET /api/ready` returned 503. Body omitted `ownerActionRequired` and `contractRevision`. Missing exactly `SUPABASE_SERVICE_ROLE_KEY`. `#147` is on main at `a9331e6b`. GitHub production deployment `6829196191` succeeded on a Vercel alias. That alias is not `resonancenexus.netlify.app`. Owner gate plus deploy lag.
- Conduit `/health` and `/ready` both 200, version 0.8.0, `contractRevision=2026-10-03-ready-surface`, ready persistence postgres.
- This repo main is `5eb30beb` after `#216`. `#217` (M3-T4 routing config) stays open until iOS Simulator Build and UI smoke are green. Simulator CI is not CHR-55.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify `resonancenexus` only. Do not invent it. Exit: public `/api/ready` is 200 and `ownerActionRequired` is false.

## Phase 2 — Deploy lag kill

`#147` landed. Exit remaining: public ready body contains `contractRevision` `2026-10-03-owner-gate`. A Vercel status does not close this.

## Phase 3 — Conduit header and health parity

Met on the live host at 16:01Z. Do not treat the old split as current.

## Phase 4 — Quicksilver routing config

Merge `#217` only if Simulator Build and UI smoke are green. Exit: M3-T4 on main. Device HG still open.

## Phase 5 — Persistence proof

After Phase 1, smoke the real 200 body on `resonancenexus`. Exit: smoke passes there, not on a preview.

## Phase 6 — Chamber fail-closed stays

No new provider. Exit: chamber tests stay red-free.

## Phase 7 — Hygiene prune

No hourly audit files. One roadmap file. Do not merge Conduit `#119`, `#120`, or `#155`. Legacy twin close still 403.

## Phase 8 — iOS cockpit only after the app target is green

Do not start a second client. Resonance `#134` is diverged. Exit: one iOS target.

## Phase 9 — Grant and bridge audit

Conduit grants stay deny-by-default. Exit: no resource record holds a secret.

## Phase 10 — Cross-plane acceptance

One probe covers Conduit ready, public Resonance ready, and Quicksilver posture parse. Exit: all three green on public hosts. A classifier unit test is not that proof.

Binding constraint: owner secret on Netlify. Agent work cannot close Phase 1.
