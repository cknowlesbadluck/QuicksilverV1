# Portfolio 10-phase roadmap — 2026-09-26 11:06 EDT

Owner-blocked items stay owner-blocked. Agents do not invent Netlify secrets or claim device HG.
Update this file and `docs/AUDIT-2026-09-25.md` only.

1. **Ready-or-refuse on main** — DONE (Resonance #108). Live still 503 until SERVICE_ROLE is set.
2. **Owner: set resonancenexus env + schema** — Exit: `GET https://resonancenexus.netlify.app/api/ready` 200. Apply `supabase/migrations` including `20260925120000_execution_partial_status.sql`. Confirmed still missing SERVICE_ROLE at 11:06. Env names present: URL, ANON, AUTH_MODE, DEPLOY_STAGE, PROJECT_ID.
3. **Prove durable GitHub vertical slice** — member-only evidence after restart; deny proofs. Needs live `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET`.
4. **Device HG CHR-55** — Archive IPA on iPhone 16e from QuicksilverV1 `871706d9` or later. GitHub Actions success is not acceptance.
5. **Quicksilver next code slice after HG** — CHR-12 realm a11y, or first on-device AI turn after Covenant bind. P-T1/P-T2/P-T3 shipped. P-T4 stays behind M3.5-T4.
6. **Conduit freeze + repair red drafts** — keep #119/#120 draft. Recut off `102c5387` / product `5659a495` only. Do not merge red.
7. **Conduit #125 keyset pagination** — DONE. Merged 2026-09-26T12:09:14Z.
8. **Resonance iOS I1** — blocked by phase 2. Codex SideStore #116/#117 closed (packaging red).
9. **Chamber lifecycle slice** — do not start while live ready is 503.
10. **Release surface** — SideStore/IPA evidence, unskip production-smoke, owner prune leftover refs, archive abandoned `Quicksilver` repo.
