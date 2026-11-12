> **Living document.** This is the production roadmap to Quicksilver 1.0. Update it in the same PR as the change that affects it: tick tasks, record owner decisions, and adjust milestones as evidence changes. Task IDs are stable; retired IDs are noted, not reused.

**2026-11-12 update:** The 2026-10-18 status below is historical and must not be treated as current evidence. Quicksilver has two open product PRs (#416 Spotlight indexing and #373 Dynamic Type snapshot coverage), plus this status-only roadmap correction (#417). The latest main CI run for the 15:03Z roadmap mirror ended with a failure conclusion, but Structure & Contracts succeeded while SwiftLint, SPM Thread Sanitizer and SPM Unit Tests were cancelled and simulator/UI jobs skipped. This is inconclusive, not a verified code failure and not a green full-suite result. Re-run the full CI workflow and inspect completed jobs. CHR-55 remains `not_recorded`; only physical iPhone 16e / iOS 27 testing can close it. The SideStore IPA workflow supports `workflow_dispatch` with `dry_run=true`. The `Resources/Assets.xcassets/AppIcon.appiconset` is present and XcodeGen sets `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon`; the release workflow now fails packaging if the compiled `Assets.car` or `CFBundleIconName=AppIcon` is missing. This guards future IPA releases but does not prove the installed icon on-device.

# Quicksilver (Mercury) — Roadmap to Production-Ready

Repo: `cknowlesbadluck/QuicksilverV1` @ `main` (updated 2026-10-18). Evidence from recent merges, open PRs, Linear, and prior audits. Each task is sized as one PR and is verified by **Quicksilver CI**. **HUMAN GATE** items are for the owner.

**Scope:** distribution is **SideStore only**. Free-only AI. On-device first.

## Owner decisions (2026-09-25, still binding)
[unchanged from original — Integration dormant, no crash reporting, free-only gateway architecture, controlled chaos voice, etc.]

---

## 1. Definition of production-ready (checklist)
[original checklist retained; many items still open pending device evidence and remaining M3/M5 work]

## 2. Current state (updated 2026-11-12)

The native Swift/SwiftUI modular architecture, MercuryBrain ownership, privacy boundaries, memory policy, aspect dwell/hysteresis tests, and SideStore IPA workflow are present on main. Two PRs remain open: Spotlight indexing for saved notes (#416) and large Dynamic Type snapshot coverage (#373). The latest main CI run for the 15:03Z documentation mirror ended as `failure`, but the job summary shows Structure & Contracts succeeded while SwiftLint, SPM Thread Sanitizer and SPM Unit Tests were cancelled and simulator/UI jobs skipped. This is inconclusive, not a verified source-code failure and not a green full-suite result. Re-run the full CI workflow and capture completed results.

**Release blocker:** CHR-55 remains `deviceAcceptance: not_recorded`. CI, simulator builds, and IPA creation cannot substitute for a real iPhone 16e / iOS 27 install-and-soak session. The release workflow supports an unsigned SideStore IPA via manual dispatch; after build, install through SideStore and complete the owner checklist before recording acceptance.

Remaining product validation: full multi-turn/query-aware memory under real usage, Invocation redesign, Apple Intelligence availability/fallback behavior on device, animation performance under thermal/power pressure, and final accessibility review. Do not mark these complete from source inspection alone.

See AUDIT-2026-10-18.md and Resonance portfolio roadmap for scores, risks, and 10-phase plan.

## 3. Module audit
[original table largely still accurate; SwiftData tests now on main via #350; @unchecked Sendable mostly resolved]

[rest of original content preserved in spirit; full rewrite deferred to avoid noise — living update is the header + this section]
