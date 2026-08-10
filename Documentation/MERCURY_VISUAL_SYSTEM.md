# Mercury: Quicksilver Visual System

## Figma master design

**Figma:** https://www.figma.com/design/Hv0hmiIuEJ36lWteRczi7H

File: `Mercury — Quicksilver Visual System`

The Figma file contains the visual direction for the native iOS experience:

- `Mercury — Visual System` — Sanctum master composition plus design tokens and motion language.
- `Realms` — Forge Workshop and Eternal Observatory compositions.
- `Nexus & Settings` — realm selection, persona, integrations, memory, diagnostics, and configuration.

## Product visual doctrine

Mercury is not a dashboard. The interface is a place inhabited by Quicksilver.

### Sanctum

The home surface is a corrupted divine chamber. It should feel ancient, atmospheric, and technically alive without becoming a fantasy-game HUD.

The persistent hierarchy is:

1. Presence / chamber state
2. Quicksilver living core
3. Glyph-driven capabilities
4. Realm access
5. Environmental signals
6. Insight / contextual information
7. Ritual actions

### Realms

- **Forge Workshop:** dense, instrument-like, energetic, emerald/ember accents.
- **Eternal Observatory:** spacious, contemplative, celestial, gold/violet accents.
- **Nexus:** the realm-selection and configuration layer. It should feel like opening a hidden chamber rather than navigating a conventional settings tab.

## Tokens

| Token | Intent |
| --- | --- |
| Void | Near-black foundation |
| Sanctum Purple | Atmospheric depth and secondary emphasis |
| Quicksilver | Living state, active controls, health |
| Silver | Primary structural text |
| Forge Ember | Forge identity |
| Eternal Gold | Observatory identity |
| Panel | Translucent instrument surfaces |

## Motion

- Core pulse: ~2.8 seconds
- Realm transition: ~420 ms
- Micro interaction: ~160 ms
- Motion should communicate state, not decorate every tap.
- The Quicksilver core remains subtly alive while the screen is idle.

## SwiftUI implementation

`UI/MercuryVisualSystem.swift` contains reusable primitives for the visual system:

- `MercuryVisualTokens`
- `MercurySanctumBackdrop`
- `MercuryPresenceOrb`
- `MercuryGlassSurface`
- `MercuryRealmPill`

`QuicksilverPresenceView` now uses `MercuryPresenceOrb` as the primary visual signature.

## iPhone 14 target

Primary design canvas: **390 × 844 pt**, portrait.

The design deliberately favors native SwiftUI layout behavior, dynamic type compatibility, safe-area awareness, and lightweight vector rendering rather than rasterized artwork.
