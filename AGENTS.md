# AGENTS.md — Quicksilver / Mercury

## Project
Native iOS intelligence platform. Primary target: iPhone 14 / iOS 27. CI floor: iOS 18.0.

## Identity: non-negotiable
- Mercury is **one entity** with one identity, one memory, one relationship model, and one intelligence pipeline.
- Quicksilver is Mercury's default expression: witty, mocking, intelligent, loyal, challenging, sharp, and humorous.
- Forge is Mercury's creative/experimental expression.
- Eternal is Mercury's Codex/automation/system expression.
- Never implement Quicksilver, Forge, or Eternal as independent AI identities, memories, agents, or providers.
- Use **aspect/expression** terminology instead of persona switching for new architecture.

## Core architecture
- Sense → Context → Think → Express → Act.
- Nexus senses the device/environment and exposes connection points.
- Mercury intelligence owns intent, context, memory retrieval, expression resolution, provider routing, and action planning.
- UI observes Mercury state. UI does not select providers, memory stores, Relics, or Glyph implementations.
- DependencyContainer remains the composition root.
- Core owns shared contracts and models.
- Public Apple APIs only. SideStore-first. No private APIs.
- Keep strict Swift concurrency.

## Capability architecture
- **Relics are tools/instruments.** They perform operations for Mercury.
- **Glyphs are connectors.** They connect Mercury to Apple surfaces, external systems, or future connector protocols.
- All Relic/Glyph discovery and invocation routes through `CapabilityBroker`.
- Every capability declares permissions, data access, transmission policy, risk, and availability.
- Never invoke a Relic or Glyph directly from a SwiftUI view or provider implementation.

## AI provider architecture
Mercury uses one default and two secondary free-tier dependencies:
1. **Gemini** — default general-purpose provider.
2. **Groq** — secondary, especially for low-latency requests and first fallback.
3. **OpenRouter free routing** — tertiary fallback across currently available free models.

Provider choice is contextual and health-aware. Do not assume a specific free model remains available forever. Keep provider-specific code behind `AIProvider` and `MercuryProviderRouter`.

Core functionality must remain operable without a paid provider.

## Personality / expression
- `MercuryIdentity` owns persistent identity and permanent traits.
- `MercuryExpression` is continuous and blendable. Do not use mutually exclusive persona switching for new work.
- `AspectResolver` determines expression from context, intent, realm, memory relevance, task type, and current Mercury state.
- Personality may change how Mercury communicates, never what privacy, authorization, or safety rules permit.

## Realms
- **Sanctum:** Mercury's primary presence and conversation environment.
- **Nexus:** connection and capability convergence point.
- **Forge:** creation, engineering, experimentation, diagnostics, and tools.
- **Observatory:** memory, history, observations, trends, analytics, and Codex.
- Realms are environments, not personas.

## Diagnostics
- Battery diagnostics are out of scope.
- Thermal diagnostics are out of scope.
- Supported domains should use public APIs and legitimate system interfaces: device, network, DNS, connectivity, Bluetooth, media/playback, storage, logs, and security observations.
- Diagnostics produce structured observations/evidence. Do not imply private iOS access.

## Visual system
- Mercury is a place/presence, not a generic AI dashboard.
- `VisualEngine` derives visual state from Mercury expression, realm, conversation, capability state, and system observations.
- SwiftUI consumes state; it does not decide intelligence transitions.
- `PersonaTheme` is legacy terminology. New visual work should use semantic Mercury design tokens and expression/realm state.
- No magic visual constants in feature views.

## Architecture rules
- Do not turn `MercuryBrain` into a god object. It is a coordinator/facade; domain work belongs in focused services.
- Do not add duplicate AI/context pathways.
- Do not expose provider response bodies directly as user-facing errors.
- Cancellation must be structured. No untracked long-lived Tasks for UI stabilization.
- External AI requests pass through privacy/transmission policy.
- Prefer deterministic, testable intent and expression resolution.

## Agent workflow
- Small, reviewable commits.
- Inspect existing contracts before adding new ones.
- Preserve module directionality.
- Add tests for new Core behavior.
- CI must remain green before merge.
- Figma is the visual/design authority; it does not override Swift architecture.
- Humans own the merge decision.

## Canonical architecture documents
- `Documentation/MERCURY_ARCHITECTURE_2.md` — current architecture contract.
- `Documentation/ARCHITECTURE.md` — implementation overview.
- `Documentation/HARDENING.md` — security and release constraints.
