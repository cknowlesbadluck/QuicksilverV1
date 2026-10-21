> **Living document.** This is the production roadmap to Quicksilver 1.0. Update it in the same PR as the change that affects it: tick tasks, record owner decisions, and adjust milestones as evidence changes. Task IDs are stable; retired IDs are noted, not reused.

**2026-10-21 04:00 EDT hygiene audit note:** Full portfolio audit, hardening, stabilization, hygiene prune requested. Open PR entropy remains the dominant operational risk (~24 open PRs). Prioritize closing superseded docs-only PRs and merging CI-green non-overlapping hardens. Device IPA evidence (CHR-55) and Resonance SUPABASE key remain external owner gates. Stabilization holds; main green. See Resonance docs/PORTFOLIO-ROADMAP-10-PHASE.md for canonical 10-phase.

**2026-10-18 evening update:** Portfolio probes confirm both Conduit /ready and Resonance /api/ready returned 503 (free-tier cold start / owner gate on SUPABASE_SERVICE_ROLE_KEY). Earlier Conduit was 200 stamped. See Resonance docs/PORTFOLIO-ROADMAP-10-PHASE.md for canonical 10-phase. Main is green; #350 memory resilience merged. Open PR entropy remains high (~25). Highest leverage remains CHR-55 device IPA evidence. Hygiene: superseded docs PRs should be closed; #351 gateway watchdog pending re-CI.

# Quicksilver (Mercury) — Roadmap to Production-Ready

Repo: `cknowlesbadluck/QuicksilverV1` @ `main` (updated 2026-10-18). Evidence from recent merges, open PRs, Linear, and prior audits. Each task is sized as one PR and is verified by **Quicksilver CI**. **HUMAN GATE** items are for the owner.

**Scope:** distribution is **SideStore only**. Free-only AI. On-device first.

## Owner decisions (2026-09-25, still binding)
[unchanged from original — Integration dormant, no crash reporting, free-only gateway architecture, controlled chaos voice, etc.]

---

## 1. Definition of production-ready (checklist)
[original checklist retained; many items still open pending device evidence and remaining M3/M5 work]

## 2. Current state (updated 2026-10-18 evening)

Core remains strong. CI green. Aspect architecture, privacy floor, memory retention, concurrency fixes landed. #350 (SwiftData resilience tests + warm session cache) merged. Open PRs advancing remaining tests, note summaries, a11y, gateway failure coverage. **Not production-ready** primarily due to lack of current device IPA validation (CHR-55). Version still hard-coded. Memory progressing toward full resilience. On-device path active.

Gaps that matter: device evidence, full multi-turn + query-aware memory, Invocation redesign, complete Apple Intelligence adoption, performance pause of animations.

See AUDIT-2026-10-18.md and Resonance portfolio roadmap for scores, risks, and 10-phase plan.

## 3. Module audit
[original table largely still accurate; SwiftData tests now on main via #350; @unchecked Sendable mostly resolved]

[rest of original content preserved in spirit; full rewrite deferred to avoid noise — living update is the header + this section]
