# Portfolio 10-phase roadmap — 2026-09-25 15:07 EDT

Owner-blocked items stay owner-blocked. Agents do not invent Netlify secrets or claim device HG.

1. **Ready-or-refuse on main** — DONE this hour (#108 merged). Live still 503 until SERVICE_ROLE is set.
2. **Owner: set resonancenexus env** — `SUPABASE_SERVICE_ROLE_KEY` on the existing site only. Exit: `GET /api/ready` 200.
3. **Prove durable GitHub vertical slice** — authenticated member executes `github.repository.read` once; execution + event + evidence survive restart; other project and anonymous caller cannot.
4. **Device HG CHR-55** — Archive IPA on iPhone 16e. Simulator green is not acceptance.
5. **Quicksilver next code slice after HG** — realm a11y (CHR-12) or first on-device AI turn after Covenant bind. Do not start until HG is recorded.
6. **Conduit freeze + repair red drafts** — keep #119/#120 draft until verify+postgres green on current main; do not land schema-at-runtime removal until migrate runner is production-wired.
7. **Conduit #125 keyset pagination** — merge only after required GitHub checks green. Ignore Cloudflare Workers Builds as a merge gate unless production moves off Render.
8. **Resonance iOS I1** — compose → plan → approve → execute → evidence against a ready host. Blocked by phase 2.
9. **Chamber lifecycle slice** — form / work / dissolve with audit intact. Not before durable evidence works.
10. **Release surface** — SideStore/IPA evidence, Privacy Manifest, production-smoke unskipped, branch entropy down to main + one active feature branch per repo.
