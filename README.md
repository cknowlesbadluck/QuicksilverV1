# Quicksilver

Native iOS intelligence framework: modular architecture, adaptive personas, Nexus diagnostics, Memory, and AI.

**Primary device target:** iPhone 14 / **iOS 27**  
**Build floor (CI / SideStore IPA):** iOS 18.0 — intentional so current GitHub runners can still produce installable binaries that run on iOS 27.  
**Current ship:** 0.2.0 (**build 7**)

```
SENSE (Nexus) → THINK (Core + AI + Memory) → EXPRESS (Personas + UI)
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

- **Slice A (persona experience)** — merged to `main` (PR #52). PersonaTheme accents, density, InsightPresenter tone, Memory policy visibility, Ask bubble styling.
- **Slice C (richer automation / Siri surface)** — in review (PR #53). PersonaEntity-typed ForcePersona, SwitchToForge, OpenDiagnostics, expanded natural phrases, still ≤ 10 App Shortcuts.
- **Sentry** — fully integrated (DSN + refined options + automatic dSYM upload on Archive).
- SideStore hardening remains solid (Privacy Manifest, monitor isolation, Archive verification). See [Documentation/HARDENING.md](Documentation/HARDENING.md).

## Surfaces

| Screen | Role |
|--------|------|
| **Home** | Persona switcher + accent, Nexus health, latest insight |
| **Ask** | Persona-aware chat with Memory history |
| **Memory** | Policy-filtered notes, delete / clear / export |
| **Diagnostics** | Live insights + signals |
| **Settings** | xAI key (Keychain) + AI feature flag |

## Architecture

[Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md)

Core owns contracts. Modules implement. UI only presents. Nexus stays persona-agnostic.

## Local Mac workflow (optional)

```bash
brew install xcodegen
xcodegen generate
open Quicksilver.xcodeproj
# or: swift test
```

Requires Xcode with an iOS SDK. CI currently uses the iOS 18 SDK; the resulting binary runs on iOS 27.

## Installation

Recommended ways to install opencode tooling for local development and mobile workflows:

- Direct installer (fast, but security risk — runs a remote script):

```bash
curl -fsSL https://opencode.ai/install | bash
```

- npx installer (requires Node.js / npm):

```bash
npx opencode-mobile install
```

You can run the included helper scripts in this repository:

```bash
bash scripts/install-opencode.sh       # direct pipe installer (requested)
bash scripts/install-opencode-npx.sh   # npx installer (safer if you have Node)
```

### AICTRL local tooling

The repo now includes helper scripts for AICTRL telemetry tooling and the Cursor plugin.
Use environment variables locally rather than inline secrets.

```bash
export AICTRL_API_KEY='your-key-here'
bash scripts/install-aictrl-telemetry.sh
bash scripts/install-aictrl-cursor-plugin.sh
# or: bash scripts/install-aictrl-all.sh
```

Full setup notes: [Documentation/LOCAL_TOOLING.md](Documentation/LOCAL_TOOLING.md)

Security note: piping remote scripts into a shell executes code from the network; review before running in sensitive environments.

This repository also includes editor and Codespaces recommendations to make working with Swift easier (.vscode/extensions.json and .devcontainer/devcontainer.json).

## On-device (iPhone 14 / iOS 27) — SideStore path

Full instructions: **[Documentation/SIDESTORE.md](Documentation/SIDESTORE.md)**

1. Trigger **Actions → Archive IPA → Run workflow** (Release).
2. Download the **Quicksilver-unsigned-IPA** artifact from the finished run.
3. Install the IPA in SideStore (LocalDevVPN connected).
4. Settings → paste xAI key → enable AI Service.
5. Validate Home → Diagnostics → Memory → Ask → persona switch (accent + tone).

No private APIs. Public Apple frameworks only. Compatible with free Apple ID + 7-day refresh cycle.

## Personas

| Persona | Role |
|---------|------|
| Quicksilver | Adaptive daily intelligence |
| Forge | Disciplined builder |
| Eternal | Continuity & long-term coherence |

Prompts: `Resources/Personas/*.txt` (embedded fallback if missing).

## Principles

- Privacy first, on-device by default
- Modular boundaries non-negotiable
- Focused commits, working vertical slices
- No autonomous agent loops

## License

Private / All rights reserved until otherwise stated.
