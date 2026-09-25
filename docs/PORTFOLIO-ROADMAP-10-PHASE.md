# Portfolio 10-phase roadmap — 2026-09-25 18:03 EDT

Owner-blocked items stay owner-blocked. Agents do not invent Netlify secrets or claim device HG.
Stop adding timestamped PORTFOLIO-AUDIT-HHMM files. Update this file and `docs/AUDIT-2026-09-25.md` only.

1. **Ready-or-refuse on main** — DONE (Resonance #108). Live still 503 until SERVICE_ROLE is set.
2. **Owner: set resonancenexus env + schema** — site id `7fc56cb3-d5f7-4bb2-8986-a733b8cfd548`. First apply required `supabase/migrations` including `20260925120000_execution_partial_status.sql`, then set `SUPABASE_SERVICE_ROLE_KEY`. Exit: `GET https://resonancenexus.netlify.app/api/ready` 200 only after both schema and key are in place (do not treat key-only as ready).
3. **Prove durable GitHub vertical slice** — member-only `github.repository.read` evidence that survives restart; other-project and anonymous callers denied. Requires scoped `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET` on the same site.
4. **Device HG CHR-55** — Archive IPA on iPhone 16e from QuicksilverV1 `b940bef6` or later. GitHub Actions / Codemagic success is not acceptance.
5. **Quicksilver next code slice after HG** — CHR-12 realm a11y, or first on-device AI turn after Covenant bind. Dependabot #154 is chore only. Do not treat Sentry as a substitute for HG.
6. **Conduit freeze + repair red drafts** — keep #119/#120 draft until verify + postgres-coordination are green on current main.
7. **Conduit #125 keyset pagination** — merge only after rebase onto `2eb338bd` and required checks are green. Workers Builds is irrelevant to this PR.
8. **Resonance iOS I1** — compose → plan → approve → execute → evidence against a ready host. Blocked by phase 2. Leave `feature/ios-p4-compose-execute-evidence` until the host is ready.
9. **Chamber lifecycle slice** — form / work / dissolve with audit intact. Do not start while live ready is 503.
10. **Release surface** — SideStore/IPA evidence, Privacy Manifest review, unskip production-smoke, owner prune of leftover `docs/portfolio-audit-*` refs (no delete-ref tool on this connector). Archive or lock the abandoned `Quicksilver` repo.
