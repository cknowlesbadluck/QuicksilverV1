# Portfolio 10-phase roadmap — 2026-10-09 13:00 EDT

Probe at 2026-10-09T17:02Z. Conduit `/health` and `/ready` 200, version 0.8.0, contractRevision `2026-10-03-ready-surface`, postgres. Resonance `/api/ready` 503, missing exactly `SUPABASE_SERVICE_ROLE_KEY`, body omits `ownerActionRequired` and `contractRevision`. Vercel aliases `resonance-nexus.vercel.app` and `resonancenexus.vercel.app` returned 404 `DEPLOYMENT_NOT_FOUND`, classified `alias_absent`. Supabase Resonance, Quicksilver, WhereamI are INACTIVE. Device HG on iPhone 16e unrecorded. No secret invented.

Spine revision `2026-10-09-phase-spine`. Current phase is 0.

## Phase 0 — Owner gate

Unpause Resonance Supabase, then set `SUPABASE_SERVICE_ROLE_KEY` on Netlify `resonancenexus` only. Do not invent it. Exit: public `GET /api/ready` is 200 and the project is not paused.

## Phase 1 — Entropy collapse

Discretionary open pulls stay at or under 2 per active repo. Automation holds do not count. Orphan fence branches with no open pull were pruned this pass: `feat/pause-before-secret`, `feat/phase-admission-1000`, `hygiene/platform-drift-fence`, `hygiene/chunk-advisory-fence`, `hygiene/roadmap-1200-refresh`. Exit: those names are not reopened.

## Phase 2 — Ready parity

Public Netlify ready body matches the known 503 contract. A Vercel alias 404 is `alias_absent`. Satisfied at this probe.

## Phase 3 — Persistence proof

Apply `supabase/migrations` on the unpaused project. Exit: production smoke against `resonancenexus`. Blocked by phase 0.

## Phase 4 — Idempotent execution

Duplicate requests do not double-execute. Exit: Idempotency-Key replay does not double-write on the production host.

## Phase 5 — Adapter substitution

A second provider satisfies the same capability contract. Exit: substitution test green. Conduit stays project-agnostic.

## Phase 6 — Chamber lifecycle

Form, work, dissolve, audit intact. Dissonance block can dissolve. Watch cannot. Durable evidence waits on phase 3. `#157` stays unmerged until that evidence exists.

## Phase 7 — iOS peer contract

One capability model on web and iOS. Do not revive closed cockpit pulls.

## Phase 8 — Device acceptance

Owner records the iPhone 16e human gate. A merged device-fence pull is not this exit.

## Phase 9 — Release hardening

SideStore IPA evidence and Postgres TLS only after the owner sets Render env. Keep-red `#155` and `#162` stay unmerged. `release/0.8.0` is hold-not-delete.
