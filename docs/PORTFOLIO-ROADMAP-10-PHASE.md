# Portfolio 10-phase roadmap — 2026-10-02 01:00 EDT

Evidence from this pass. Live probes at 2026-10-02T05:01Z.

1. QuicksilverV1 is the only intelligence-platform repo. `cknowlesbadluck/Quicksilver` is a stale Studio twin. `mcp` is archived. Do not implement on either.
2. Main is ca83b13 after #201. #202 is the open motion branch. UI smoke failed contrast on an unnamed AccessibilityNode. This commit hides the decorative ambient canvas, freezes it under Reduce Motion, and lifts caption copy off 0.55 opacity. Exit: required checks and UI smoke green, then squash. Do not merge the red head 36ca6ec.
3. Device HG remains the product gate. Archive IPA on iPhone 16e from the commit that contains phase 2. CHR-55. Simulator CI is not acceptance.
4. Owner sets SUPABASE_SERVICE_ROLE_KEY on resonancenexus only. Live ready is 503, production, missing exactly that key. Do not invent it. Do not switch hosts.
5. Conduit stays frozen on #119, #120, #155, and #162. Live ready is 200, postgres, 0.8.0, boundAgent grok, no binding conflict.
6. Resonance readiness posture (owner vs agent) ships on its own branch. Do not squash #141 or #142 while github-advanced-security is red.
7. Accessibility is not done at merge. Device VoiceOver on the HG IPA is the proof.
8. SideStore install proof of the HG IPA. No proof exists.
9. Prune only branches that are not open PR heads. Hourly PORTFOLIO-AUDIT files stay forbidden.
10. Post-deploy hardening: signed Conduit cursors only after Render TLS env is set; then close the red drafts.

Binding constraints this pass cannot close: owner secret on Netlify, physical iPhone 16e, Render TLS env before #155/#162.
