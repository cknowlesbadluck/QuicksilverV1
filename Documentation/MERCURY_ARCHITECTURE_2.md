# Mercury Architecture 2.0

## 1. One Entity

Mercury is one entity. Quicksilver, Forge, and Eternal are not independent personas or agents.

- **Quicksilver** is Mercury's default expression: witty, mocking, intelligent, loyal, crude when appropriate, challenging, sharp, scathing, and humorous.
- **Forge** is Mercury's creative/experimental expression. It surfaces when invention, engineering, architecture, or experimentation dominates the context.
- **Eternal** is Mercury's codex/automation/system expression. It surfaces when structured knowledge, procedures, automation, governance, or long-horizon reasoning dominates the context.

The system must preserve one identity, one memory, one relationship model, and one intelligence pipeline.

## 2. Identity vs Expression

`MercuryIdentity` owns persistent identity and permanent behavioral traits.

`MercuryExpression` describes the current blend of aspects and behavioral dimensions. Expression is contextual and continuous rather than a mutually exclusive persona switch.

Conceptual flow:

```text
Input → Context → Intent → Aspect Resolution → Mercury Expression → Response
```

The expression resolver may produce blends such as:

```text
Quicksilver 0.70 / Forge 0.25 / Eternal 0.05
```

The aspects modify expression, not identity.

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

No UI surface should select an AI provider, memory implementation, or tool implementation directly.

## 4. AI Provider Routing

The application uses one default provider and two secondary providers. Provider choice is contextual and health-aware.

### Default: Google Gemini 2.5 Flash

Use Gemini 2.5 Flash as the default general-purpose provider because it combines a large context window, strong multimodal capability, and a currently free developer tier. It is the primary conversational/reasoning path.

### Secondary: Groq

Use Groq as the fast secondary provider for latency-sensitive requests and as the first fallback when the default provider is unavailable, rate-limited, or unsuitable for a request.

### Tertiary/Fallback: OpenRouter free router

Use OpenRouter's `openrouter/free` as the final provider fallback. It can route across currently available free models and supports capabilities such as tools and structured outputs where the selected model supports them. Free capacity and model availability are inherently variable, so this provider must never be assumed to be permanent.

### Routing policy

```text
                    Request
                       ↓
               Provider Router
                       │
          ┌────────────┼────────────┐
          ↓            ↓            ↓
       Gemini        Groq       OpenRouter
       DEFAULT      SECONDARY     FALLBACK
          │            │            │
          └────────────┴────────────┘
                       ↓
                 Provider Result
```

The router evaluates:

- request type
- required capabilities
- context size
- latency requirement
- provider health
- rate-limit state
- temporary failures
- privacy policy
- provider capability compatibility

The router must not silently downgrade a request when the fallback cannot satisfy its required capabilities.

## 5. Relics and Glyphs

### Relic

A **Relic** is an instrument Mercury can invoke to perform an operation.

Examples:

- network analysis
- DNS inspection
- log analysis
- file inspection
- diagnostics
- data transformation
- code analysis
- automation execution

```swift
protocol MercuryRelic: Sendable {
    var id: RelicID { get }
    var manifest: RelicManifest { get }
    func invoke(_ request: RelicRequest) async throws -> RelicResult
}
```

### Glyph

A **Glyph** is a connector between Mercury and an external system or platform surface.

Examples:

- App Intents
- Shortcuts
- Siri
- Files
- Share Sheet
- Contacts
- Calendar
- external APIs
- future connector protocols

```swift
protocol MercuryGlyph: Sendable {
    var id: GlyphID { get }
    var manifest: GlyphManifest { get }
    func connect() async throws
    func disconnect() async
}
```

A Relic is an instrument. A Glyph is a connection.

## 6. Capability Broker

Mercury never invokes Relics or Glyphs directly from the brain.

`CapabilityBroker` is the single gateway for discovery, authorization, validation, invocation, and result normalization.

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

Every capability declares permissions, data access, transmission behavior, supported realms, supported expressions, and risk level.

## 7. Codex

The Codex belongs to Mercury. Eternal is its keeper/expression, not a separate owner.

The Codex contains:

- structured knowledge
- procedures
- automation definitions
- capability manifests
- rules
- durable system knowledge

## 8. Realms

- **Sanctum:** Mercury's primary presence and conversation environment.
- **Nexus:** Mercury's connection and capability convergence point.
- **Forge:** creation, engineering, experimentation, diagnostics, and tool use.
- **Observatory:** memory, history, observations, trends, analytics, and Codex views.

Realms are environments, not personas.

## 9. Diagnostics

Battery and thermal diagnostics are intentionally excluded.

Supported diagnostic domains are limited to capabilities that can be implemented through legitimate public iOS APIs and available system interfaces:

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

## 10. Memory

All memory belongs to Mercury.

Domains:

- working
- episodic
- semantic
- preference
- relationship
- system observations
- Codex

Aspect state influences retrieval and presentation, not ownership.

## 11. Event System

`MercuryEventBus` is the internal nervous system.

Events include:

- conversation
- response
- aspect
- realm
- memory
- capability
- relic
- glyph
- diagnostic
- automation
- system
- visual

Events are domain events, not UI callbacks.

## 12. Privacy Boundary

Every context item and capability declares a transmission classification:

- `localOnly`
- `sensitive`
- `restricted`
- `neverTransmit`
- `providerSafe`

External provider requests pass through a privacy policy before transmission.

Personality must never override privacy, authorization, or safety rules.

## 13. UI and Visual Engine

SwiftUI consumes Mercury state rather than implementing intelligence decisions.

`VisualEngine` derives visual state from:

- Mercury expression
- realm
- conversation state
- capability state
- system observations

The living quicksilver presence is a state visualization, not merely decoration.

## 14. Architecture Rules

1. There is only one Mercury.
2. Never implement Quicksilver, Forge, or Eternal as separate AI identities.
3. Do not turn `MercuryBrain` into a god object.
4. UI does not select providers or invoke tools directly.
5. Relics are tools; Glyphs are connectors.
6. Capability execution passes through `CapabilityBroker`.
7. All external provider requests pass through privacy policy.
8. Core functionality must not depend on a paid provider.
9. Public iOS APIs only.
10. Battery and thermal diagnostics are out of scope.
11. Prefer deterministic, testable routing and expression resolution.
12. Preserve strict Swift concurrency.
13. Architecture documents are contracts for human and AI contributors.
