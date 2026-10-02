# Portfolio 10-phase roadmap — 2026-10-02 04:00 EDT

Evidence from this pass. Live probes at 2026-10-02T08:01:44Z.

1. QuicksilverV1 is the only intelligence-platform repo. `cknowlesbadluck/Quicksilver` is a stale Studio twin. `mcp` is archived. Do not implement on either.
2. Main is 5cd560d7 after #202 (Reduce Motion + contrast). UI smoke was green on 0015d46. Owner-gate board plus probe witness is on `feat/owner-gate-board`. Do not merge until required checks and UI smoke are green. Simulator text is not proof.
3. Device HG remains the product gate. Archive IPA on iPhone 16e from the commit that contains phase 2. CHR-55. Simulator CI is not acceptance.
4. Owner sets SUPABASE_SERVICE_ROLE_KEY on resonancenexus only. Live ready is 503, production, missing exactly that key. Do not invent it. Do not switch hosts.
5. Conduit stays frozen on #119, #120, #155, and #162. Live ready is 200, postgres, 0.8.0, boundAgent grok, no binding conflict. #164 Workers Builds failed; do not merge.
6. Resonance readiness posture is #144. Do not squash #141 or #142 while they still overlap #144. Do not merge a red required check.
7. Accessibility is not done at merge. Device VoiceOver on the HG IPA is the proof.
8. SideStore install proof of the HG IPA. No proof exists.
9. Prune only branches that are not open PR heads. Hourly PORTFOLIO-AUDIT files stay forbidden.
10. Post-deploy hardening: signed Conduit cursors only after Render TLS env is set; then close the red drafts.

Binding constraints this pass cannot close: owner secret on Netlify, physical iPhone 16e, Render TLS env before #155/#162.
