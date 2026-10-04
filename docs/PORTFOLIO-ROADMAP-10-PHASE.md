# Portfolio 10-phase roadmap — 2026-10-03 22:00 EDT

Live probes at 2026-10-04T02:00:45Z. No secrets invented. This file is refreshed in place on #218. Do not open another roadmap PR.

Evidence:
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned **503**. Body: `status=not_ready`, `missingRequired=[SUPABASE_SERVICE_ROLE_KEY]`, `authMode=required`, `authModeOk=true`, `persistenceConfigured=false`, `githubAdapterConfigured=false`. Body omitted `ownerActionRequired` and `contractRevision`. Owner gate plus deploy lag. Not proof.
- Resonance `GET /api/health` returned **200**.
- Conduit `GET /health` and `GET /ready` both returned **200**, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`. Health parity is live. Do not reopen it.
- Conduit diagnostics: health, PRM, AS, JWKS, scope parity all ok. Bound agent `grok`, no binding conflict.
- QuicksilverV1 main `c388442b`. Open: #221 multi-turn, #218 this roadmap, #209 dependabot. Simulator CI is not device acceptance.
- activity_prune removed 0.

## Phase 1 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: public `/api/ready` is 200 and the body includes `contractRevision`.

## Phase 2 — Kill deploy lag

Public host still omits `ownerActionRequired` and `contractRevision`. A green GitHub deployment on a Vercel alias is not the public gate. Exit: `resonancenexus.netlify.app` serves the committed contract.

## Phase 3 — Conduit health parity

Done on the live host at 2026-10-04T02:00Z. Exit already met. Do not land a second health-contract PR for this.

## Phase 4 — Quicksilver device gate

#221 is the product slice (multi-turn history). Do not merge it on simulator green alone. Exit: device HG on iPhone 16e, CHR-55 closed with evidence.

## Phase 5 — Open-PR freeze

Conduit has 9 open pulls. Actionable count is over the budget of 3. KEEP RED #119 and #120 stay unmerged. #155 stays unmerged until Render TLS env is set. Exit: one classifier lands or the rest close. A new classifier is not progress.

## Phase 6 — Persistence proof

After Phase 1, run production smoke against the real 200 body on `resonancenexus`, not a preview. Exit: smoke passes and `persistenceConfigured=true`.

## Phase 7 — Hygiene prune

No hourly audit files. One roadmap file per repo, updated in place. Legacy `cknowlesbadluck/Quicksilver` is not the product. Close #1 and #2 there if the token allows; a 403 is an owner action.

## Phase 8 — One iOS target

Resonance #134 stays open until it builds or is closed. Do not start a second client. Exit: one buildable iOS target.

## Phase 9 — Grant and bridge stay deny-by-default

No resource record holds a secret. Exit: grant tests green and bridge calls still require an explicit grant.

## Phase 10 — Cross-plane acceptance

One probe covers Conduit ready, Resonance ready, and Quicksilver posture. Exit: all three green on production. A unit test is not that proof.

Binding constraint: owner secret on Netlify. Agent work cannot close Phase 1.
