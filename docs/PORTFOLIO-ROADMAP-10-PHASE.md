# Portfolio 10-phase roadmap — 2026-10-08 23:00 EDT

Live probes at 2026-10-09T03:01:18Z. No secrets invented. A classifier is not production proof. This file is the in-place roadmap. Do not add hourly audit files. Do not open a new witness family.

Evidence:
- Conduit `GET /health` and `GET /ready` returned 200. `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, persistence `postgres`. Bound agent `grok`, no binding conflict.
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. Body omitted `ownerActionRequired` and `contractRevision`.
- `https://resonancenexus.vercel.app/api/ready` returned 404 `DEPLOYMENT_NOT_FOUND`. Classify as `alias_absent`, not an owner gate.
- Legacy `cknowlesbadluck/Quicksilver` is already archived.
- Collapse receipt `2026-10-08-2300-collapse` closes superseded witness families and deletes their heads. Keep-red `#119` `#120` `#155` `#162` stay open and their branches stay. Canonical lattice pulls stay open: Conduit `#187`, Resonance `#154`, QuicksilverV1 `#242`. Device-acceptance `#241` and Dependabot `#209` stay open.

## Phase 0 — Owner gate

Set `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200. Agent work cannot close this phase.

## Phase 1 — Entropy collapse

Exit: superseded pulls closed, their heads deleted, keep-red untouched, no new witness family. This pass executes that exit. Remaining open non-keep-red work is the lattice family, `#241`, and `#209`.

## Phase 2 — Ready parity

After Phase 0, public Netlify ready body matches the repository contract revision. A Vercel alias success does not count.

## Phase 3 — Persistence proof

Apply `supabase/migrations` on the real project. Exit: production smoke passes against `resonancenexus`, not a side alias.

## Phase 4 — Idempotent execution

Duplicate requests do not double-execute. Exit: Idempotency-Key covered by a production-shaped test on main.

## Phase 5 — Adapter substitution

One real adapter vertical slice, plus a second provider behind the same capability model. Exit: substitution test green without Conduit becoming Resonance-specific.

## Phase 6 — Chamber lifecycle

Form, work, dissolve, audit intact. Exit: chamber tests green and fail-closed when a capability is not executable.

## Phase 7 — iOS peer contract

One capability model on web and iOS. Exit: no dual model on main. Do not revive closed cockpit pulls.

## Phase 8 — Device acceptance

iPhone 16e human gate. Simulator CI is not this gate. `#241` stays open until that gate is recorded. Mercury gateway deploy remains owner-only.

## Phase 9 — Release hardening

SideStore IPA evidence, privacy manifest, Postgres TLS only after the owner sets Render env. Exit: keep-red `#155` and `#162` either merged against a prepared env or still explicitly unmerged.

Binding constraint: owner secret on Netlify. The collapse receipt does not pretend otherwise.
