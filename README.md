# Quicksilver

**Mercury: Quicksilver** is a native iOS intelligence environment built around one persistent Mercury entity, contextual expressions, modular capabilities, memory, and spatial realms.

**Primary device:** iPhone 14 / iOS 27  
**Deployment floor:** iOS 18.0  
**Current app version:** 0.2.0 (build 7)

## Architecture

```text
Sense → Context → Think → Express → Act
```

- **Nexus** observes available device/environment signals.
- **MercuryBrain** coordinates intent, context, memory, expression, provider routing, and action planning.
- **Relics** are instruments Mercury can invoke.
- **Glyphs** connect Mercury to Apple surfaces and external systems.
- **CapabilityBroker** is the authorization and invocation boundary.
- **Sanctum, Nexus, Forge, and Observatory** are realms, not separate personalities.

Mercury is one entity. Quicksilver, Forge, and Eternal are expressions of that entity and share identity, memory, relationship, and intelligence.

See [Documentation/MERCURY_ARCHITECTURE_2.md](Documentation/MERCURY_ARCHITECTURE_2.md) for the architecture contract and [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) for the implementation overview.

## AI provider strategy

The application is designed around one default and two secondary free-tier-oriented providers:

1. Gemini — default general-purpose provider.
2. Groq — secondary / latency-oriented fallback.
3. OpenRouter free routing — tertiary fallback across currently available free models.

Provider-specific code stays behind the AI provider abstraction and routing layer. Core functionality must remain operable without a paid provider.

## Visual system

Mercury is a **place**, not a generic AI dashboard. The primary experience is the Sanctum, with Forge and Observatory as functional realms and Codex as Mercury's governance/knowledge surface.

Figma is the visual authority for design intent, components, tokens, motion, and interaction specifications. SwiftUI implements those specifications within the project's architecture and iOS constraints.

## Diagnostics

Battery and thermal diagnostics are not part of the core architecture. Supported diagnostic work must use legitimate public iOS APIs and available system interfaces.

## Cloud development

The repository is designed to be developed and validated without a local Mac. GitHub Actions provides the CI and SideStore-oriented archive path.

Typical CI gates include:

| Gate | Purpose |
|---|---|
| Structure & Contracts | Verify modular boundaries and required project contracts |
| SwiftLint | Strict linting |
| SPM Unit Tests | Validate Core and modular behavior |
| iOS Simulator Build | Generate the Xcode project and build the app/test targets |
| Archive IPA | Produce the unsigned SideStore artifact |

## Sentry

Sentry is used as optional runtime observability and crash evidence. It must remain behind the project's observability boundary and must not receive unnecessary private conversation, memory, credential, or sensitive data.

Archive builds can upload dSYMs when the appropriate Sentry authentication secret is configured.

## Development workflow

```text
Linear
  ↓
Architecture / Design specification
  ↓
Figma + Codex / Grok / Cursor
  ↓
GitHub branch + PR
  ↓
Code review + CI
  ↓
iPhone 14 validation
  ↓
Sentry runtime evidence
  ↓
Linear completion
```

Keep commits small and reviewable. Do not merge speculative rewrites. Architecture changes require corresponding updates to the architecture contract and tests.

## On-device / SideStore

See [Documentation/SIDESTORE.md](Documentation/SIDESTORE.md) for the current SideStore workflow.

The project uses public Apple APIs only and targets an unsigned IPA workflow suitable for SideStore re-signing.

## Principles

- Privacy first.
- One Mercury entity, shared memory and identity.
- Modular boundaries are non-negotiable.
- UI observes intelligence state rather than implementing intelligence decisions.
- Relics are instruments; Glyphs are connectors.
- Figma defines visual intent; SwiftUI owns implementation.
- Small, testable, reviewable changes.
- No autonomous agent loops.
