# Mercury: Quicksilver — Architecture

## Vision

Mercury is a personal AI operating companion for iPhone. The user enters the Sanctum rather than opening a generic dashboard.

There is one entity: **Mercury**.

Quicksilver is Mercury's default expression. Forge and Eternal are contextual aspects of the same entity, not separate personas or agents.

## Core Model

```text
                         MERCURY
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
       Identity        Intelligence       Capabilities
          │                 │                 │
          │           Context + Intent       │
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
                    Aspect / Expression
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
         Quicksilver       Forge        Eternal
           default        creative      codex/system
```

## Intelligence Pipeline

```text
Input
 → Intent
 → Context Assembly
 → Memory Retrieval
 → Aspect Resolution
 → Privacy Policy
 → Provider Routing
 → Response Processing
 → Mercury Expression
 → Visual / Voice / UI State
```

`MercuryBrain` is a coordinator/facade, not a god object. Domain responsibilities belong to focused services.

## AI Provider Stack

Mercury uses one default and two secondary free-tier dependencies:

1. **Gemini 2.5 Flash** — default general-purpose provider.
2. **Groq** — secondary/fast path and first fallback.
3. **OpenRouter `openrouter/free`** — tertiary fallback across available free models.

The router evaluates context, capability requirements, provider health, rate limits, latency, and privacy policy. Provider-specific implementations remain behind `AIProvider`.

## Relics and Glyphs

**Relics are instruments/tools.** They perform operations for Mercury.

**Glyphs are connectors.** They connect Mercury to Apple surfaces, external systems, or future connector protocols.

All discovery and invocation goes through `CapabilityBroker` and registered `RelicRegistry` / `GlyphRegistry` instances.

Each capability declares:

- permissions
- data accessed
- transmission policy
- risk level
- availability
- supported realms/aspects

## Realms

| Realm | Purpose |
|---|---|
| **Sanctum** | Mercury's primary presence and conversation environment |
| **Nexus** | Connection and capability convergence point |
| **Forge** | Creation, engineering, experimentation, diagnostics, and tools |
| **Observatory** | Memory, history, observations, trends, analytics, and Codex |

Realms are environments, not personalities.

## Personality / Expression

`MercuryIdentity` owns persistent identity and baseline traits.

`MercuryExpression` is continuous and blendable. It may combine Quicksilver, Forge, and Eternal rather than switching between mutually exclusive personas.

- **Quicksilver:** witty, mocking, intelligent, loyal, crude when appropriate, challenging, sharp, scathing, humorous.
- **Forge:** creative, experimental, technically obsessed, energetic, inventive, mad-scientist intensity layered over Quicksilver.
- **Eternal:** direct, precise, semi-aloof, systems-oriented, keeper of the Codex and automation, layered over Quicksilver.

Personality affects expression, never privacy, authorization, or safety constraints.

## Memory

All memory belongs to Mercury. There are no separate Forge/Eternal memories.

Memory domains:

- working
- episodic
- semantic
- preference
- relationship
- system observations
- Codex

## Diagnostics

Battery and thermal diagnostics are intentionally excluded.

Supported diagnostic domains are limited to legitimate public iOS capabilities:

- device
- network
- DNS
- connectivity
- Bluetooth
- media/playback
- storage
- logs
- security observations

Diagnostics produce structured observations and evidence. They do not imply privileged access to private iOS internals.

## Event System

`MercuryEventBus` is the internal event fabric for conversation, aspect, realm, memory, capability, Relic, Glyph, diagnostic, automation, system, and visual events.

Events are domain events, not UI callbacks.

## Privacy Boundary

Every context item and capability has a transmission classification such as `localOnly`, `sensitive`, `restricted`, `neverTransmit`, or `providerSafe`.

External provider requests pass through a privacy policy before transmission.

## Visual System

`VisualEngine` derives visual state from Mercury expression, realm, conversation state, capability state, and system observations.

The living quicksilver presence is a state visualization. Visual effects should communicate Mercury's current state without requiring explicit persona selection.

## Engineering Rules

- Swift 6 strict concurrency.
- SwiftUI for presentation.
- Dependency injection at the composition root.
- Public Apple APIs only.
- SideStore-first distribution.
- Modular boundaries are non-negotiable.
- UI does not select AI providers or invoke Relics/Glyphs directly.
- Core functionality must not require a paid AI provider.
- Prefer deterministic, testable routing and expression resolution.
- Do not create duplicate intelligence/context pathways.
