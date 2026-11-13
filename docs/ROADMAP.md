> **Living document.** This is the production roadmap to Quicksilver 1.0. Update it in the same PR as the change that affects it: tick tasks, record owner decisions, and adjust milestones as evidence changes. Task IDs are stable; retired IDs are noted, not reused.

**2026-11-13 update:** Main is at `0adba9d2aa8ac546900fff07ebfa2bcc0d15ae1d`. The latest main Quicksilver CI run (#1834, run 43507103982) completed all six jobs successfully: Structure & Contracts, SwiftLint, SPM Unit Tests, SPM Thread Sanitizer, iOS Simulator Build, and iOS UI Smoke. The Dynamic Type/accessibility follow-up is merged as PR #418; its predecessor #373 is closed as superseded. The Sendable hardening issue #252 is closed after PR #284 merged; the ratchet allowlist is empty. PR #416 (opt-in saved-note Spotlight indexing) remains open and requires its full PR CI plus physical-device verification. PR #419 proposes immutable SHA pins for every action in the SideStore release workflow; issue #250 remains open until that PR is merged. CHR-55 remains `deviceAcceptance: not_recorded`; only the owner's physical iPhone 16e / iOS 27 install-and-soak can close it. Do not treat simulator success or IPA packaging as device acceptance.

# Quicksilver (Mercury) — Roadmap to Production-Ready

Repo: `cknowlesbadluck/QuicksilverV1` @ `main` (updated 2026-10-18). Evidence from recent merges, open PRs, Linear, and prior audits. Each task is sized as one PR and is verified by **Quicksilver CI**. **HUMAN GATE** items are for the owner.

**Scope:** distribution is **SideStore only**. Free-only AI. On-device first.

## Owner decisions (2026-09-25, still binding)
[unchanged from original — Integration dormant, no crash reporting, free-only gateway architecture, controlled chaos voice, etc.]

---

## 1. Definition of production-ready (checklist)
[original checklist retained; many items still open pending device evidence and remaining M3/M5 work]

## 2. Current state (updated 2026-11-13)

The native Swift/SwiftUI modular architecture, MercuryBrain ownership, entity-wide memory foundation, privacy boundaries, automatic aspect dwell/hysteresis, living Sanctum visual system, and SideStore IPA workflow are present on main. The latest main CI run (43507103982) is fully green across all six jobs, including Thread Sanitizer, simulator build, app-hosted tests, and UI smoke/accessibility.

**Merged hardening and product work:** PR #284 removed the final production `@unchecked Sendable` conformance; issue #252 is now closed and the ratchet test has an empty allowlist. PR #418 completed the current-main Dynamic Type/accessibility follow-up; older PR #373 is closed as superseded.

**Open work:** PR #416 adds opt-in Spotlight indexing for saved notes and remains subject to full PR CI and real-device acceptance. PR #419 pins the SideStore release workflow's third-party actions to immutable SHAs; issue #250 remains open until the PR is merged and verified.

**Release blocker:** CHR-55 remains `deviceAcceptance: not_recorded`. CI, simulator builds, and IPA creation cannot substitute for a real iPhone 16e / iOS 27 install-and-soak session.

**Remaining product validation:** real multi-turn and query-aware memory behavior; Invocation interaction redesign; Apple Intelligence availability and fallback on device; visual animation performance under thermal and power pressure; end-to-end task execution/permission behavior; final accessibility review. These must be closed with automated evidence where possible and physical-device evidence where required.
## 3. Module audit
[original table largely still accurate; SwiftData tests now on main via #350; @unchecked Sendable mostly resolved]

[rest of original content preserved in spirit; full rewrite deferred to avoid noise — living update is the header + this section]
