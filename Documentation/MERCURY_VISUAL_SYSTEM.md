# Mercury: Quicksilver Visual System

## Figma master design

**Figma:** https://www.figma.com/design/Hv0hmiIuEJ36lWteRczi7H

File: `Mercury — Quicksilver Visual System`

The Figma file defines the native iOS visual direction:

- `Mercury — Visual System` — master composition, materials, tokens, and motion language.
- `Realms` — Forge Workshop and Eternal Observatory compositions.
- `Nexus & Settings` — realm selection, persona, integrations, memory, diagnostics, and configuration.

## Product visual doctrine

Mercury is a **place**, not a dashboard. Quicksilver is experienced through a living material system rather than conventional AI-chat chrome.

The visual identity is built from two coupled ideas:

### Controlled Chaos

The environment is dynamic, nonlinear, and spatial, but never arbitrary. Sparse traces, drifting particles, broken orbital structures, asymmetric energy, and layered depth create movement inside a stable visual grammar.

Chaos has boundaries. The eye should always perceive a center, a hierarchy, and a direction of flow.

### Living Mercury

The Quicksilver core is matter, not an icon. Its boundary subtly deforms; its highlights move independently; its reflections slide across a metallic surface; and its surrounding field responds to state.

Idle state is a slow breath. Listening, thinking, processing, and speaking progressively increase surface energy, field density, and orbital activity. Reduce Motion collapses the system to a stable material rendering rather than disabling the identity entirely.

## Persistent hierarchy

1. Quicksilver presence / state
2. Living mercury core
3. Glyph-driven capabilities
4. Realm access
5. Environmental signals
6. Insight / contextual information
7. Ritual actions

## Realms

- **Forge Workshop:** dense, instrument-like, energetic, emerald/ember accents.
- **Eternal Observatory:** spacious, contemplative, celestial, gold/violet accents.
- **Nexus:** the realm-selection and configuration layer; it should feel spatial and intentional rather than like a conventional settings tab.

## Material language

| Token | Intent |
| --- | --- |
| Void | Near-black foundation |
| Glow Purple | Atmospheric depth and secondary emphasis |
| Toxic Green | Live state, health, Forge energy |
| Mercury Silver | Structural text and metal surface |
| Mercury Bright | Hard specular reflection |
| Mercury Shadow | Depth beneath the reflective surface |
| Mercury Blue | Cool reflected-metal variation |
| Chaos Field | Sparse environmental motion |
| Chaos Trace | Broken orbital / structural linework |

## Motion

- Core pulse: approximately 2.8 seconds.
- Realm transition: approximately 420 ms.
- Micro interaction: approximately 160 ms.
- Fluid surface: continuously deforming at lightweight vector cadence.
- Controlled-chaos field: slow independent drift around the core.
- Motion communicates state; it is not decoration for every interaction.
- Accessibility Reduce Motion preserves the material hierarchy while removing continuous deformation and environmental motion.

## SwiftUI implementation

The visual system is split between reusable primitives and the living core:

- `UI/PersonaTheme.swift` — authoritative visual/material tokens, including controlled-chaos geometry.
- `UI/MotionTokens.swift` — shared motion vocabulary.
- `UI/MercuryVisualSystem.swift` — reusable atmospheric surfaces and presence primitives.
- `UI/QuicksilverCoreView.swift` — procedural living-mercury surface and controlled-chaos field.
- `UI/QuicksilverPresenceView.swift` — presence composition around the core.

The core uses lightweight SwiftUI `Canvas` rendering rather than rasterized artwork so it remains appropriate for the iPhone 14 target and scales with the native layout system.

## iPhone 14 target

Primary design canvas: **390 × 844 pt**, portrait.

The design favors native SwiftUI layout behavior, dynamic type compatibility, safe-area awareness, accessibility, and procedural vector rendering.
