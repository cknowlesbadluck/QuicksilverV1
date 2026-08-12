# Mercury Architecture 2.0

## 1. One Entity

Mercury is one entity. Quicksilver, Forge, and Eternal are expressions, not independent personas or agents.

- **Quicksilver** is Mercury's default expression: witty, intelligent, skeptical, sharp, humorous, and loyal.
- **Forge** is Mercury's creative and experimental expression.
- **Eternal** is Mercury's Codex, automation, governance, and long-horizon expression.

The system preserves one identity, one memory, one relationship model, and one intelligence pipeline.

## 2. Identity vs Expression

`MercuryIdentity` owns persistent identity and permanent traits.

`MercuryExpression` describes the current blend of aspects and behavioral dimensions. Expression is contextual and continuous, rather than a mutually exclusive persona switch.

```text
Input → Context → Intent → Aspect Resolution → Mercury Expression → Response
```

## 3. Intelligence Pipeline

```text
User Input
  ↓
Intent Analysis
  ↓
Context Assembly
  ├─ conversation
  ├─ relevant memory
  ├─ current realm
  ├─ system observations
  ├─ available capabilities
  └─ Mercury expression
  ↓
Privacy / Transmission Policy
  ↓
Provider Routing
  ↓
Response Processing
  ↓
Mercury Expression
  ↓
Visual / Voice / UI State
```

No UI surface selects an AI provider, memory implementation, or capability implementation directly.

## 4. AI Provider Routing

Mercury uses one default and two secondary free-tier-oriented providers. Availability and limits are variable, so provider-specific assumptions must remain isolated behind abstractions.

1. **Gemini** — default general-purpose provider.
2. **Groq** — secondary and latency-oriented fallback.
3. **OpenRouter free routing** — tertiary fallback across currently available free models.

The router evaluates request type, required capabilities, context size, latency requirements, provider health, rate limits, temporary failures, privacy policy, and capability compatibility.

A fallback must not silently downgrade a request when it cannot satisfy the request's required capabilities.

## 5. Relics and Glyphs

A **Relic** is an instrument Mercury can invoke to perform an operation. Examples include network analysis, DNS inspection, log analysis, file inspection, diagnostics, data transformation, code analysis, and automation execution.

A **Glyph** is a connector between Mercury and an external system or platform surface. Examples include App Intents, Shortcuts, Siri, Files, Share Sheet, Contacts, Calendar, and future connector protocols.

```text
Mercury
  ↓
CapabilityBroker
  ├─ RelicRegistry
  └─ GlyphRegistry
       ↓
Permission / Privacy Policy
       ↓
Invocation
       ↓
Result / Event
```

A Relic is an instrument. A Glyph is a connection.

## 6. Capability Broker

`CapabilityBroker` is the single gateway for capability discovery, authorization, validation, invocation, and result normalization.

Every capability declares permissions, data access, transmission behavior, supported realms, supported expressions, risk level, and availability.

SwiftUI views and provider implementations must never invoke Relics or Glyphs directly.

## 7. Codex

The Codex belongs to Mercury. Eternal is its keeper/expression, not a separate owner.

The Codex contains structured knowledge, procedures, automation definitions, capability manifests, rules, and durable system knowledge.

## 8. Realms

- **Sanctum:** Mercury's primary presence and conversation environment.
- **Nexus:** connection and capability convergence point.
- **Forge:** creation, engineering, experimentation, diagnostics, and tools.
- **Observatory:** memory, history, observations, trends, analytics, and Codex.

Realms are environments, not personas.

## 9. Diagnostics

Battery and thermal diagnostics are intentionally excluded from core architecture.

Supported diagnostic domains are limited to capabilities implementable through legitimate public iOS APIs and available system interfaces, including device, network, DNS, connectivity, Bluetooth, media/playback, storage, logs, and security observations.

Diagnostics produce structured observations and evidence. They must not imply privileged access to private iOS internals.

## 10. Memory

All memory belongs to Mercury. Domains include working, episodic, semantic, preference, relationship, system observations, and Codex knowledge.

Aspect state influences retrieval and presentation, not ownership.

## 11. Event System

`MercuryEventBus` is the internal domain-event nervous system.

Events may describe conversation, response, aspect, realm, memory, capability, relic, glyph, diagnostic, automation, system, and visual state.

Events are domain events, not UI callbacks.

## 12. Privacy Boundary

Every context item and capability declares a transmission classification such as:

- `localOnly`
- `sensitive`
- `restricted`
- `neverTransmit`
- `providerSafe`

External provider requests pass through privacy policy before transmission.

Personality never overrides privacy, authorization, or safety rules.

## 13. UI and Visual Engine

SwiftUI consumes Mercury state rather than implementing intelligence decisions.

`VisualEngine` derives visual state from Mercury expression, realm, conversation state, capability state, and system observations.

The living quicksilver presence is a state visualization, not merely decoration.

Figma defines visual intent, components, tokens, motion, and interaction specifications. SwiftUI remains responsible for implementation within the established architecture and platform constraints.

## 14. Architecture Rules

1. There is only one Mercury.
2. Quicksilver, Forge, and Eternal are expressions, not separate AI identities.
3. Do not turn `MercuryBrain` into a god object.
4. UI does not select providers or invoke capabilities directly.
5. Relics are tools; Glyphs are connectors.
6. Capability execution passes through `CapabilityBroker`.
7. External provider requests pass through privacy policy.
8. Core functionality must not depend on a paid provider.
9. Public iOS APIs only.
10. Battery and thermal diagnostics are out of scope for core architecture.
11. Prefer deterministic, testable routing and expression resolution.
12. Preserve strict Swift concurrency.
13. Architecture documents are contracts for human and AI contributors.
