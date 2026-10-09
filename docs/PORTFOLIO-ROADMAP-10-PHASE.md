# Portfolio 10-phase roadmap — 2026-10-09 03:00 EDT

Live probes at 2026-10-09T07:01Z. No secrets invented. A classifier is not production proof. This file is the in-place roadmap. Do not add hourly audit files. Do not open a new witness family.

Evidence:
- Conduit `GET /health` and `GET /ready` returned 200. `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, persistence `postgres`. Diagnostics ok. Bound agent `grok`, no binding conflict.
- Resonance `GET https://resonancenexus.netlify.app/api/ready` returned 503. `missingRequired` is exactly `SUPABASE_SERVICE_ROLE_KEY`. Body omitted `ownerActionRequired` and `contractRevision`.
- Supabase Resonance, Quicksilver, and WhereamI were `INACTIVE` at 01:00 EDT. Pause stands until the owner unpauses.
- `https://resonancenexus.vercel.app/` returned 404 `DEPLOYMENT_NOT_FOUND`. Classify as `alias_absent`.
- Legacy `cknowlesbadluck/Quicksilver` is archived.
- `#241` squash-merged at `83f13504`. Device fence is `landed_unverified`. Simulator CI on `#242` is not the human gate.
- Open pulls on this repo: `#242` and `#209`. Discretionary count is 2, inside budget. Do not close `#209`.
- `activity_prune` removed 0.

## Phase 0 — Owner gate

Unpause Resonance Supabase, then set `SUPABASE_SERVICE_ROLE_KEY` on Netlify `resonancenexus` only. Do not invent it.

## Phase 1 — Entropy collapse

Discretionary open pulls are at most 2. Met. `#209` stays.

## Phase 2 — Ready parity

Public Netlify ready body matches the repository contract revision. A Vercel alias success does not count.

## Phase 3 — Persistence proof

Apply migrations on the unpaused Resonance project. A key against a paused project is not proof.

## Phase 4 — Idempotent execution

Duplicate requests do not double-execute on the production host.

## Phase 5 — Adapter substitution

A second provider behind the same capability model. Conduit stays project-agnostic.

## Phase 6 — Chamber lifecycle

Form, work, dissolve, audit intact, fail-closed when a capability is not executable.

## Phase 7 — iOS peer contract

One capability model on web and iOS. Do not revive closed cockpit pulls.

## Phase 8 — Device acceptance

`#241` is on main and is not this exit. Owner records the iPhone 16e human gate. Mercury gateway deploy remains owner-only.

## Phase 9 — Release hardening

SideStore IPA evidence and Postgres TLS only after the owner sets Render env. Keep-red `#155` and `#162` stay unmerged until then.

Binding constraint: paused Supabase plus missing Netlify key. Lattice revision `2026-10-09-landed-fence`.
