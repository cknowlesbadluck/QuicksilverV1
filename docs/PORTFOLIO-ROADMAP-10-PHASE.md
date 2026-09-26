# Portfolio 10-phase roadmap — 2026-09-26 07:09 EDT

Owner-blocked items stay owner-blocked. Agents do not invent Netlify secrets or claim device HG.
Update this file and `docs/AUDIT-2026-09-25.md` only.

1. **Ready-or-refuse on main** — DONE (Resonance #108). Live still 503 until SERVICE_ROLE is set.
2. **Owner: set resonancenexus env + schema** — Exit: `GET https://resonancenexus.netlify.app/api/ready` 200. Apply `supabase/migrations` including `20260925120000_execution_partial_status.sql`.
3. **Prove durable GitHub vertical slice** — member-only evidence after restart; deny proofs. Needs live `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET`.
4. **Device HG CHR-55** — Archive IPA on iPhone 16e from QuicksilverV1 `22d4da1d` or later. GitHub Actions success is not acceptance.
5. **Quicksilver next code slice after HG** — CHR-12 realm a11y, or first on-device AI turn after Covenant bind. P-T2 shipped (#157).
6. **Conduit freeze + repair red drafts** — keep #119/#120 draft. #135 merged. Recut limiter only with a test that oldest keys leave first.
7. **Conduit #125 keyset pagination** — merge only after rebase onto current main (`eab12882`) and required checks are green.
8. **Resonance iOS I1** — blocked by phase 2. Codex SideStore #116/#117 closed (packaging red).
9. **Chamber lifecycle slice** — do not start while live ready is 503.
10. **Release surface** — SideStore/IPA evidence, unskip production-smoke, owner prune leftover refs, archive abandoned `Quicksilver` repo.
