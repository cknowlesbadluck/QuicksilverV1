# Portfolio 10-phase roadmap — 2026-10-01 13:07 EDT

1. QuicksilverV1 stays the only intelligence-platform repo. Studio twin is not the product.
2. M2-T6 view-model tests — DONE. Squashed #200 at fde95967.
3. On-device text overlap on the ask path, 4-item cap, no vectors. This pass, on #201. Exit: required checks plus UI smoke green, then squash.
4. Device HG: archive IPA on iPhone 16e from the commit that contains phase 3. CHR-55. Simulator CI is not acceptance.
5. Owner sets SUPABASE_SERVICE_ROLE_KEY on resonancenexus only. Exit: GET /api/ready 200. Live is still 503 missing that key only. Do not invent it.
6. Conduit freeze. Do not merge #119/#120/#155/#162 while required or deploy checks are red.
7. Resonance portfolio gate #142 stays open until GHAS is green or explicitly non-required.
8. Accessibility and reduced-motion pass. CHR-12. Dynamic Type on Sanctum portals is the current slice.
9. SideStore install proof of the HG IPA.
10. Owner prune leftover branches. This connector has no delete-ref tool. Do not add hourly audit files.
