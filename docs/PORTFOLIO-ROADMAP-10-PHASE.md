# Portfolio 10-phase roadmap — 2026-10-08 14:00 EDT

Live probes at 2026-10-08T18:01:50Z. No secrets invented. Simulator CI is not device acceptance.

Evidence:
- Conduit ready 200, version 0.8.0, contractRevision `2026-10-03-ready-surface`, postgres.
- Resonance public ready 503, missing exactly `SUPABASE_SERVICE_ROLE_KEY`, body omits `ownerActionRequired` and `contractRevision`.
- Vercel alias 404 `DEPLOYMENT_NOT_FOUND`, classified `alias_absent`.
- Lattice pull requests stay open: Conduit #187, Resonance #154, QuicksilverV1 #242. Posture pin refreshed in place. No new witness. Gateway is not deployed by this change.
- Device HG on iPhone 16e remains the product gate.

## Phase 0 — Owner gate
Owner sets `SUPABASE_SERVICE_ROLE_KEY` on Netlify `resonancenexus` only.

## Phase 1 — Entropy collapse
No new witness while the lattice pull request is open and the pin holds.

## Phase 2 — Ready parity
Public Netlify body matches the contract. Vercel alias absence is not the gate.

## Phase 3 — Persistence proof
Smoke on the real 200 host.

## Phase 4 — Idempotent execution
Duplicate requests never double-execute.

## Phase 5 — Adapter substitution
One capability model, provider behind it.

## Phase 6 — Chamber lifecycle
Form, work, dissolve, audit.

## Phase 7 — One iOS peer
QuicksilverV1 only. Legacy Quicksilver stays archived when the token can.

## Phase 8 — Device acceptance
iPhone 16e. Not simulator CI. Not a gateway deploy from this pin.

## Phase 9 — Release hardening
TLS only after owner env. Privacy manifest and SideStore evidence.

Binding constraint: owner secret, then device HG.
