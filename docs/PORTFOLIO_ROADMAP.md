# Portfolio cutover roadmap

Observed 2026-10-08 10:00 EDT. No secrets invented. Agent archive of `cknowlesbadluck/Quicksilver` remains 403.

This is the single admissible sequence. The cutover lattice refuses later phases while an earlier gate is open.

## Live facts used

| Surface | Result |
| --- | --- |
| Conduit `/health` and `/ready` | 200, version `0.8.0`, contract `2026-10-03-ready-surface`, persistence `postgres` |
| Resonance `https://resonancenexus.netlify.app/api/ready` | 503, missing exactly `SUPABASE_SERVICE_ROLE_KEY`, body omits `ownerActionRequired` and `contractRevision` |
| `resonancenexus.vercel.app` | 404 `DEPLOYMENT_NOT_FOUND`, class `alias_absent` |
| Open pull requests | Conduit 8, Resonance 3, QuicksilverV1 4 |
| Branch hygiene | No orphan branches. Every non-main branch is an open pull request head |
| Predecessor | `cknowlesbadluck/mcp` archived. `cknowlesbadluck/Quicksilver` still public |

## Phase 0 — Owner gates

- Goal: close the only gates an agent cannot close.
- In scope: owner sets `SUPABASE_SERVICE_ROLE_KEY` on Netlify `resonancenexus`; owner archives `cknowlesbadluck/Quicksilver`.
- Out of scope: inventing the key, switching hosts, merging keep-red database TLS pull requests.
- Exit: public `/api/ready` is no longer missing that key; predecessor repo is archived.
- Admission: owner only.

## Phase 1 — Entropy collapse

- Goal: one admissible feature pull request per repository, keep-red fenced and labeled.
- In scope: merge or close superseded witness branches; leave `#119`, `#120`, `#155`, `#162` unmerged while required checks are red.
- Out of scope: a new witness document pull request.
- Exit: open pull requests at or under 2 per active repository, excluding labeled keep-red.
- Admission: implement after Phase 0, or in parallel only as close/rebase work.

## Phase 2 — Ready parity

- Goal: public ready body matches the source contract.
- In scope: Netlify serves current `main`; contract fields stay omitted until the owner key exists.
- Out of scope: a second public host.
- Exit: `/api/ready` 200 with persistence configured, or an explicit 503 whose missing list is empty of undeclared fields.

## Phase 3 — Persistence proof

- Goal: migrations applied, including execution partial status.
- In scope: Supabase migrations, ready persistence flag, no service-role value in git.
- Exit: ready reports persistence configured and a migration smoke passes.

## Phase 4 — Idempotent execution

- Goal: intent to plan to execute to evidence, with duplicate requests not double-executing.
- In scope: Idempotency-Key on the Nexus execute path.
- Exit: replay test proves one execution record.

## Phase 5 — Adapter substitution

- Goal: a second provider satisfies the same capability contract.
- In scope: one non-GitHub adapter behind the existing port.
- Exit: catalog resolve works with either adapter and no product core import of the vendor SDK.

## Phase 6 — Chamber lifecycle

- Goal: form, work, dissolve, audit intact.
- In scope: Agenda-driven Chamber on main, evidence retained after dissolve.
- Exit: one chamber fixture completes without a leftover claim.

## Phase 7 — iOS peer contract

- Goal: one capability model on web and iOS.
- In scope: delete the dual iOS model if it still exists; App Intents call the same contract.
- Exit: contract test fails if the iOS model diverges.

## Phase 8 — Device acceptance

- Goal: human gate on iPhone 16e, not simulator CI.
- In scope: SideStore install, Sanctum, Workshop, Memory, Ask, diagnostics.
- Exit: owner records device evidence. Simulator green is not this exit.

## Phase 9 — Release hardening

- Goal: signed cursors and database TLS only after the owner sets the env; privacy manifest and IPA evidence attached.
- In scope: Conduit `#155` / `#162` after Render env; Quicksilver archive IPA artifact linked.
- Exit: required checks green, keep-red labels removed, activity retention prune returns a bounded count.

## Explicit non-goals

- Do not merge red required checks.
- Do not store secrets in Conduit resource records.
- Do not make Conduit Resonance-specific.
- Do not treat the Vercel alias 404 as the Resonance owner gate.
