# Portfolio 10-phase roadmap — 2026-10-01 20:00 EDT

Evidence, not intent. Live probes at 20:01 EDT.

1. QuicksilverV1 is the only intelligence-platform repo. `cknowlesbadluck/Quicksilver` is a stale twin. `mcp` is archived. Do not implement there.
2. M2-T6 view-model tests are on main. Squashed #200 at fde95967. Do not reopen.
3. On-device text overlap on the ask path stays on #201. 20:00 UTC UI smoke passed destinations and failed `testSanctumAccessibilityAudit` on Forge StaticText (Dynamic Type partially unsupported). This commit collapses each portal to one button and drops line-limited caption2. Exit: UI smoke and required checks green on the new head, then squash. Do not merge the red head d3726845.
4. Device HG: archive IPA on iPhone 16e from the commit that contains phase 3. CHR-55. Simulator CI is not acceptance.
5. Owner sets SUPABASE_SERVICE_ROLE_KEY on resonancenexus only. Exit: GET /api/ready 200. Live at 2026-10-02T00:01:50Z is 503, production, authMode required, missing exactly that key. Do not invent it. Do not switch hosts.
6. Conduit stays frozen. Live ready is 200, postgres, 0.8.0, boundAgent grok, no binding conflict. Do not merge #119, #120, #155, or #162 while deploy or TLS checks are red or the Render TLS env is unset.
7. Resonance #141 and #142 stay open. web/ios/gemini are green. github-advanced-security is red on both. Do not squash red required security.
8. Accessibility and reduced motion. CHR-12. Current slice is the Forge Dynamic Type node, not another portal hit-target tweak.
9. SideStore install proof of the HG IPA. No proof exists in this pass.
10. Prune `docs/hygiene-*` branches that are not open PR heads. Hourly audit files stay forbidden.

Binding constraints that this pass cannot close: owner secret on Netlify, physical iPhone 16e, Render TLS env before #155/#162.
