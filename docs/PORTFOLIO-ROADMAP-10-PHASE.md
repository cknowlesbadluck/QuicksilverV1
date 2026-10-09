# Portfolio 10-phase roadmap — 2026-10-09 15:00 EDT

Live probes at 2026-10-09T19:01Z. No secrets invented. Merging `main` into the lattice branch is stabilization, not phase admission, and not a pull merge.

Evidence:
- Conduit `GET /health` and `GET /ready` returned 200, `version=0.8.0`, `contractRevision=2026-10-03-ready-surface`, ready `persistence=postgres`.
- Resonance `GET /api/ready` returned 503 missing exactly `SUPABASE_SERVICE_ROLE_KEY`. Body omitted `ownerActionRequired` and `contractRevision`.
- Vercel alias returned 404 `DEPLOYMENT_NOT_FOUND`, classified `alias_absent`.
- Supabase projects Resonance, Quicksilver, and WhereamI remain INACTIVE from the prior owner-gate classification. This pass did not unpause them.
- Device HG on iPhone 16e is unrecorded.
- Before this pass, lattice pulls were dirty: Conduit `#187` behind 1 (`40aeb11`), Resonance `#154` behind 1 (`278bc39`), QuicksilverV1 `#242` behind 2 (`8bc9b57`). The only merge conflict was this file.
- This pass merged `main` into `feat/cutover-lattice-1000` on each repo. The pulls stay open.

## Phase 0 — Owner gate

Unpause Resonance Supabase, then set `SUPABASE_SERVICE_ROLE_KEY` on Netlify `resonancenexus` only. Record device HG on iPhone 16e. A branch merge does not clear this. Blocked.

## Phase 1 — Lattice current

Lattice branches contain `main`. Dirty base is recorded, then closed by branch merge, not by merging `#187`, `#154`, or `#242`. Exit of this pass: branch contains main. Pull merge is still refused.

## Phase 2 — Ready parity

Public Netlify ready body matches the known 503 contract until the owner sets the key. A Vercel alias 404 stays `alias_absent`.

## Phase 3 — Persistence proof

Apply `supabase/migrations` on the unpaused Resonance project and smoke `resonancenexus`. Blocked by phase 0.

## Phase 4 — Idempotent execution

Duplicate requests do not double-execute. Exit: Idempotency-Key replay does not double-write on the production host. Blocked.

## Phase 5 — Adapter substitution

A second provider satisfies the same capability contract. Conduit stays project-agnostic. Blocked.

## Phase 6 — Chamber lifecycle

Form, work, dissolve, audit intact. Watch cannot dissolve. Dissonance can. `#157` stays unmerged until durable evidence exists. Blocked on phase 3.

## Phase 7 — iOS peer contract

One capability model on web and iOS. Do not revive closed cockpit pulls. Blocked.

## Phase 8 — Device acceptance

HG recorded on iPhone 16e. Simulator CI and gateway health are not this exit. Blocked.

## Phase 9 — Release surface

Privacy manifest, SideStore evidence, and deny-by-default grants still hold. `#155` and `#162` stay unmerged until the Render Postgres TLS env is set. `#119` and `#120` stay draft red. `release/0.8.0` is hold-not-delete.

Binding constraint: the Resonance owner secret and the unrecorded device gate. Conduit coordination surface is ready and is not production-proven for TLS or grants.
