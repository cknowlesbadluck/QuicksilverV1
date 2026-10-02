# Portfolio 10-phase roadmap — 2026-10-02 03:00 EDT

Evidence from this pass. Live probes at 2026-10-02T07:01Z.

1. QuicksilverV1 is the only intelligence-platform repo. `cknowlesbadluck/Quicksilver` is a stale Studio twin. `mcp` is archived. Do not implement on either.
2. Main is 5cd560d7 after #202. Reduce Motion and Sanctum contrast are landed. This branch adds an owner-gate board. Simulator and CI text cannot mark a gate proven. Exit: required checks and UI smoke green, then squash. Do not merge a red head.
3. Device HG remains the product gate. Archive IPA on iPhone 16e from 5cd560d7 or later. CHR-55. Simulator CI is not acceptance.
4. Owner sets SUPABASE_SERVICE_ROLE_KEY on resonancenexus only. Live ready at 2026-10-02T07:01:24Z is 503, production, authMode required, missing exactly that key. Do not invent it. Do not switch hosts.
5. Conduit stays frozen on #119, #120, #155, and #162. Live ready is 200, postgres, 0.8.0, boundAgent grok, no binding conflict. #164 stays open: Workers Builds failed, mergeable_state unstable.
6. Resonance #144 names owner vs agent readiness. CI and GHAS are green. mergeable_state is blocked. Do not force it. Do not squash #141 or #142 while github-advanced-security is red.
7. Accessibility is not done at merge. Device VoiceOver on the HG IPA is the proof.
8. SideStore install proof of the HG IPA. No proof exists.
9. Hourly PORTFOLIO-AUDIT files stay forbidden. Prune only branches that are not open PR heads. No delete-ref tool on this connector.
10. Post-deploy hardening: signed Conduit cursors only after Render TLS env is set; then close the red drafts.

Binding constraints this pass cannot close: owner secret on Netlify, physical iPhone 16e, Render TLS env before #155/#162.
