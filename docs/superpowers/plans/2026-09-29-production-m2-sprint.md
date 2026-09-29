# Quicksilver Production Sprint — M2 Verification Foundation

## Objective
Drive QuicksilverV1 through the remaining M2 test/CI foundation so later production work can proceed behind reliable regression gates. Preserve current product architecture and behavior; this sprint is hardening, not redesign.

## Scope
1. Add an injectable `DependencyContainer` seam for deterministic app-hosted tests while preserving the default production initializer.
2. Add app-hosted XCTest coverage for Codex/Ask/MercuryBrain and the Memory/Forge/Eternal view-model paths that are currently untested.
3. Add HTTP-boundary tests for Grok/Gemini providers and in-memory SwiftData persistence tests where current seams allow it; make the smallest testability changes required.
4. Change SwiftLint CI from changed-files-only to full-repository `--strict`.
5. Add an XCUITest smoke target and CI step that launches Quicksilver and traverses the shipped Sanctum destinations using deterministic test dependencies.
6. Run GitHub CI, inspect every failure, fix root causes, and repeat until required checks are green or an external Apple/runner limitation is proven.

## Constraints
- No product redesign, new architecture, paid service, or new provider.
- Preserve Quicksilver/Forge/Eternal as autonomous aspects of one entity.
- SideStore remains the supported distribution path.
- Swift 6 strict concurrency remains `complete`; do not use `@unchecked Sendable` or `nonisolated(unsafe)` as convenience fixes.
- Do not embed secrets or production provider credentials.
- Prefer existing module interfaces; add a seam only where a second adapter/test implementation makes it real.

## Verification gates
- `Structure & Contracts`: green.
- `SwiftLint`: full-repo strict, green.
- `SPM Unit Tests`: green with new provider/persistence tests where applicable.
- `iOS Simulator Build`: app build + AppTests + XCUITest smoke green.
- No new compiler concurrency warnings.
- No regressions in aspect autonomy or SideStore packaging.

## Delivery
Work on `sprint/production-m2-foundation`, open a PR to `main`, and leave the branch only when CI is green or the remaining blocker requires physical-device validation that CI cannot perform.
