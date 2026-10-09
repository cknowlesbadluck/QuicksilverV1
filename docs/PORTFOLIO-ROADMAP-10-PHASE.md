# Portfolio 10-phase roadmap — 2026-10-09 06:00 EDT

Probe: Conduit `/health` and `/ready` 200, version 0.8.0, contractRevision `2026-10-03-ready-surface`, postgres. Diagnostics health, PRM, AS, JWKS, scope parity ok. Resonance `/api/ready` 503, missing exactly `SUPABASE_SERVICE_ROLE_KEY`, body omits ownerActionRequired and contractRevision. Vercel alias 404 `DEPLOYMENT_NOT_FOUND`, classified `alias_absent`. Supabase Resonance, Quicksilver, WhereamI paused at the 01:00 probe and not rechecked this hour. Device HG on iPhone 16e unrecorded. `#241` on main at `83f13504` is landed_unverified, not the device exit. activity_prune removed 0. Governor revision `2026-10-09-phase-governor` decides current phase 0.

## Phase 0 — Owner gate

Unpause Resonance Supabase, then set `SUPABASE_SERVICE_ROLE_KEY` on Netlify `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200 and the project is not paused.

## Phase 1 — Entropy collapse

Discretionary open pulls stay at or under 2 per active repo. Automation holds do not count. Exit: Bolt `#188` and Dependabot `#209` remain open and unmerged while unstable. Satisfied at this probe (discretionary 1/1/1).

## Phase 2 — Ready parity

Public Netlify ready body matches the repository contract revision. A Vercel alias success does not count. Satisfied at this probe as the known 503 shape.

## Phase 3 — Persistence proof

Apply `supabase/migrations` on the unpaused project. Exit: production smoke against `resonancenexus`.

## Phase 4 — Idempotent execution

Duplicate requests do not double-execute. Exit: Idempotency-Key replay does not double-write on the production host.

## Phase 5 — Adapter substitution

A second provider satisfies the same capability contract. Exit: substitution test green. Conduit stays project-agnostic.

## Phase 6 — Chamber lifecycle

Form, work, dissolve, audit intact. Dissonance block can dissolve. Watch cannot. Durable evidence waits on Phase 3.

## Phase 7 — iOS peer contract

One capability model on web and iOS. Do not revive closed cockpit pulls.

## Phase 8 — Device acceptance

`#241` on main is not this exit. Owner records the iPhone 16e human gate.

## Phase 9 — Release hardening

SideStore IPA evidence and Postgres TLS only after the owner sets Render env. Keep-red `#155` and `#162` stay unmerged until then. `release/0.8.0` is diverged: hold, do not delete.
