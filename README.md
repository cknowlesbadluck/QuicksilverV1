# Quicksilver

Native iOS intelligence framework: one persistent Quicksilver entity with autonomous aspects, Nexus diagnostics, Memory, and AI.

**Primary device target:** iPhone 16e / **iOS 27**  
**Build floor (CI / SideStore IPA):** iOS 18.0 — intentional so current GitHub runners can still produce installable binaries that run on iOS 27.  
**Current ship:** 0.2.0 (**build 7**)

```
SENSE (Nexus) → THINK (Core + Brain + Memory + AI) → EXPRESS (Aspect + UI)
```

## Cloud development (no local Mac required)

Every push and pull request to `main` runs on **GitHub-hosted macOS runners**:

| Job | What it does |
|-----|----------------|
| **Structure & Contracts** | Verifies modular layout, Core protocols, and Privacy Manifest |
| **SwiftLint** | Strict lint (fails the PR on violations) |
| **SPM Unit Tests** | `swift test` for Core / Memory / Personas / Nexus / AI |
| **iOS Simulator Build** | XcodeGen → `xcodebuild` for iPhone Simulator (no signing) |

**Manual runs from your phone:** GitHub → Actions → *Quicksilver CI* → *Run workflow*.

**IPA for SideStore:** Actions → *Archive IPA* → *Run workflow*.  
Produces an unsigned IPA by default (SideStore re-signs). Optional signed path available when certificate secrets are present. Post-build checks verify app bundle, persona prompts, and IPA structure.  
When `SENTRY_AUTH_TOKEN` is configured, debug symbols are automatically uploaded to Sentry (`inbetween` / `quicksilver`).

Artifacts (logs + IPA + dSYMs) are downloadable from the workflow run page on your iPhone.

## Status

- **Aspect architecture** — merged to `main` (PR #98). IntentEngine, AspectPolicy, Brain-owned active aspect, Sanctum presence, Workshop/Observatory surfaces.
- **Provider routing** — Interim Codex bind: free Gemini key recommended; optional Grok. **If Grok is bound, it is primary** (Gemini fallback) and can consume xAI credits — bind Grok only when you already have credits. Credentials stay in Keychain. Gateway routing lands in M3.
- **Sentry** — fully integrated (DSN + refined options + automatic dSYM upload on Archive).
- **SideStore hardening** remains solid (Privacy Manifest, monitor isolation, Archive verification). See [Documentation/HARDENING.md](Documentation/HARDENING.md) and [Documentation/SIDESTORE.md](Documentation/SIDESTORE.md).
- **Hygiene (2026-09-19)** — Logger privacy defaulted to `.private`, primary validation device updated to iPhone 16e, AppConfiguration version aligned.

## Surfaces

| Screen | Role |
|--------|------|
| **Home / Sanctum** | Living Quicksilver presence + Nexus health + latest insight |
| **Workshop** | Forge aspect: creation / engineering instruments |
| **Observatory** | Eternal aspect: observation / continuity / memory |
| **Ask** | Aspect-aware conversation with Memory history |
| **Memory** | Policy-filtered notes, delete / clear / export |
| **Diagnostics** | Live insights + signals |
| **Codex** | Bind/unbind provider keys (Gemini, optional Grok) + automatic provider routing; with no key bound, Mercury shows "Intelligence unbound" |

## Architecture

[Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md)

Production roadmap to 1.0 (living document): [docs/ROADMAP.md](docs/ROADMAP.md)

Core owns contracts. Modules implement. UI only presents. Nexus stays persona-agnostic.

## Local Mac workflow (optional)

```bash
brew install xcodegen
xcodegen generate
open Quicksilver.xcodeproj
# or: swift test
```

Requires Xcode with an iOS SDK. CI selects `latest-stable` Xcode (**currently 26.3** / iOS 26 SDK); deployment target stays iOS 18.0 so the binary still installs on iOS 27 via SideStore.

## On-device (iPhone 16e / iOS 27) — SideStore path

Full instructions and first-run checklist: **[Documentation/SIDESTORE.md](Documentation/SIDESTORE.md)**  
Hardening report: **[Documentation/HARDENING.md](Documentation/HARDENING.md)**

1. Trigger **Actions → Archive IPA → Run workflow** (Release).
2. Download the **Quicksilver-unsigned-IPA** artifact from the finished run.
3. Install the IPA in SideStore (LocalDevVPN connected).
4. Codex → bind keys: free Gemini (AI Studio, no billing) and optional Grok if you already have xAI credits. Binding the first key enables intelligence.
5. Validate Sanctum / Home → Forge → Eternal → Diagnostics → Memory → Ask → aspect overrides (Quicksilver / Forge / Eternal in Diagnostics).

No private APIs. Public Apple frameworks only. Compatible with free Apple ID + 7-day refresh cycle.

## Entity and aspects

Quicksilver is the single persistent entity. Forge and Eternal are autonomous aspects surfaced by context; they are not separate personas or assistants. An aspect may be pinned per thread as a mood of the one entity; Auto is the default.

Prompts: `Resources/Personas/*.txt` provide aspect-specific behavioral grounding.

## Principles

- Privacy first, on-device by default
- Modular boundaries non-negotiable
- Focused commits, working vertical slices
- No autonomous agent loops

## License

Private / All rights reserved until otherwise stated.
