> **Living document.** This is the production roadmap to Quicksilver 1.0. Update it in the same PR as the change that affects it: tick tasks, record owner decisions, and adjust milestones as evidence changes. Task IDs are stable; retired IDs are noted, not reused.

**2026-10-18 update:** Portfolio probes confirm Conduit /ready 200 stamped, Resonance /api/ready 503 (missing SUPABASE_SERVICE_ROLE_KEY). See Resonance docs/PORTFOLIO-ROADMAP-10-PHASE.md for canonical 10-phase. Main is green; open PR entropy remains high (~27). Highest leverage remains CHR-55 device IPA evidence. Hygiene: superseded docs PRs should be closed.

# Quicksilver (Mercury) — Roadmap to Production-Ready

Repo: `cknowlesbadluck/QuicksilverV1` @ `main` (updated 2026-10-18). Evidence from recent merges, open PRs, Linear, and prior audits. Each task is sized as one PR and is verified by **Quicksilver CI**. **HUMAN GATE** items are for the owner.

**Scope:** distribution is **SideStore only**. Free-only AI. On-device first.

## Owner decisions (2026-09-25, still binding)
[unchanged from original — Integration dormant, no crash reporting, free-only gateway architecture, controlled chaos voice, etc.]

---

## 1. Definition of production-ready (checklist)
[original checklist retained; many items still open pending device evidence and remaining M3/M5 work]

## 2. Current state (updated 2026-10-18)

Core remains strong. CI green. Aspect architecture, privacy floor, memory retention, concurrency fixes landed. Open PRs advancing tests, note summaries, a11y, gateway failure coverage, memory resilience. **Not production-ready** primarily due to lack of current device IPA validation (CHR-55). Version still hard-coded. Memory progressing toward full resilience. On-device path active.

Gaps that matter: device evidence, full multi-turn + query-aware memory, Invocation redesign, complete Apple Intelligence adoption, performance pause of animations.

See AUDIT-2026-10-17.md and Resonance portfolio roadmap for scores, risks, and 10-phase plan.

## 3. Module audit
[original table largely still accurate; SwiftData tests landing in open PRs; @unchecked Sendable mostly resolved]

[rest of original content preserved in spirit; full rewrite deferred to avoid noise — living update is the header + this section]
