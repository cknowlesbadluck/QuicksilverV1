# Portfolio 10-phase roadmap — 2026-10-02 14:02 EDT

Observed, not assumed. Conduit `/health` and `/ready` 200, postgres, 0.8.0. Diagnostics ok. Bound agent `grok`, no binding conflict. Resonance `/api/ready` 503 at 2026-10-02T18:04:01Z missing exactly `SUPABASE_SERVICE_ROLE_KEY`. Body has no `ownerActionRequired`. Quicksilver main `a1da2b3`.

1. Owner sets `SUPABASE_SERVICE_ROLE_KEY` on Netlify site `resonancenexus`. Exit: `/api/ready` 200. Do not invent the secret. Do not switch hosts.
2. Apply Resonance migrations and set scoped GitHub adapter secrets. Exit: persistence and adapter configured on the same host.
3. Merge Resonance deploy-lag classifier only if CI is green (#145). Do not treat a 503 probe as a code defect.
4. Quicksilver device HG on iPhone 16e from current main. Simulator CI is not acceptance.
5. Land fail-closed Mercury endpoint policy (this branch) before any gateway worker calls a URL. #207 stays a scaffold until this gate is on main.
6. Conduit freeze: do not merge #119, #120, #155, #162 until the named env or migration proof exists.
7. Close superseded docs PRs (#163, Resonance #143) after this hygiene note lands. Do not delete PR head branches.
8. Resonance iOS I1 stays blocked by phase 1. #134 is not a substitute for a ready host.
9. Chamber lifecycle stays blocked by phase 1.
10. Release surface: owner prune of leftover non-PR refs. This connector has no delete-ref tool. `feat/witness-1501` is the same SHA as Quicksilver main.
