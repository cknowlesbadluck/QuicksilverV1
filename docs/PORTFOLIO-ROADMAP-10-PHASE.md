# Portfolio 10-phase roadmap — 2026-10-01 23:00 EDT

Evidence, not intent. Live probes at 23:00 EDT.

1. QuicksilverV1 is the only intelligence-platform repo. `cknowlesbadluck/Quicksilver` is a stale Studio twin. `mcp` is archived. Do not implement there. Archive the twin after its two open PRs are closed.
2. M2-T6 view-model tests are on main at fde95967. Do not reopen.
3. Ask-path text overlap and the Dynamic Type portal collapse are on main at ca83b13 (#201). Required checks and UI smoke were green on aadd2b9 before squash. Do not reopen #201.
4. Device HG: archive IPA on iPhone 16e from ca83b13 or later, including the reduce-motion policy once that PR is green. CHR-55. Simulator CI is not acceptance.
5. Owner sets SUPABASE_SERVICE_ROLE_KEY on resonancenexus only. Exit: GET /api/ready 200. Live at 2026-10-02T03:00:46Z is 503, production, authMode required, persistenceConfigured false, githubAdapterConfigured false, missing exactly that key. Do not invent it. Do not switch hosts.
6. Conduit stays frozen. Live health 200, ready 200, postgres, 0.8.0. Diagnostics 200 (PRM, AS, JWKS, scope parity, CIMD, DCR). Activity prune removed 0. Do not merge #119, #120, #155, or #162 while deploy or TLS checks are red or the Render TLS env is unset. #161 is a cursor micro-opt; do not merge it ahead of the TLS freeze.
7. Resonance #141 and #142 stay open. Do not squash while github-advanced-security is a required red check. #132, #133, #134 stay open until their required checks are green. Main is d27ffb42.
8. Accessibility. CHR-12. Current slice is MotionTokens.resolved on Sanctum and AmbientLayer, not another portal hit-target tweak. Exit: motion policy PR required checks green, then squash.
9. SideStore install proof of the HG IPA. No proof exists in this pass.
10. Prune branches that are not open PR heads, develop, or release. Hourly audit files stay forbidden.

Binding constraints this pass cannot close: owner secret on Netlify, physical iPhone 16e, Render TLS env before #155/#162.
