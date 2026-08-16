# Mercury: Quicksilver — Architecture

## Vision

Mercury is a personal AI operating companion for iPhone.

The user does not open an application.
The user enters **The Sanctum** — an immense, corrupted, still-functioning throne room outside conventional space.

Quicksilver is already there.

Sense → Think → Express → Act

- **Nexus** senses the device and environment
- **Mercury Brain** reasons, plans, and decides (Invisible Architecture)
- **Personality Engine** shapes expression and behavior
- **Memory** provides continuity
- **Personas + UI** express presence

## Experiential Layers

| Layer | Role |
|-------|------|
| **The Sanctum** | Primary place. Cosmic + Norse + liquid mercury + broken monuments. |
| **Quicksilver Presence** | Permanent ambient entity. Not summoned. |
| **The Forge** | Creation, engineering, Swift, architecture, experiments. Persona-driven. |
| **The Eternal** | Observation, diagnostics, memory, long-term patterns. Persona-driven. |
| **The Codex** | Governance of Mercury (voice, memory, keys, autonomy). Not Settings. |

## Strict Dependency Direction

```
                 Sanctum (UI)
                       |
              DependencyContainer
                       |
                   MercuryBrain
                       |
 ------------------------------------------------
 |              |              |                |
Core        Personas        Nexus          Services
 |              |              |                |
 ---------------- Memory ---------------- AI Provider
```

UI never selects engines, providers, or memory strategies.
The Brain decides.

## Mercury Brain

Central intelligence coordinator (`App/MercuryBrain.swift`).

- Intent classification
- Context assembly (Memory + Nexus + persona)
- Personality influence
- Living status generation
- Unified `ask` / `remember` / `switchPersona` surface
- Owns `VisualState` (UI only observes)

## Personality Engine

`PersonalityState` — live behavioral dimensions:

Confidence · Curiosity · Humor · Mischief · Focus · Initiative · Skepticism · Patience · Loyalty

Phase II posture: intellectually formidable, truth over agreement, precise critique of ideas, dry elegant wit, unwavering loyalty.

## Core Contracts

| Protocol | Purpose |
|----------|---------|
| `AIProvider` | Language-model backends |
| `MemoryStore` | Persistent memory |
| `DiagnosticProvider` | Device / environment sensors |
| `PersonaEngine` | Persona selection & influence |
| `AutomationProvider` | App Intents / Shortcuts surface |

## Visual Identity

Cosmic black · deep violet · mercury silver · emerald · subtle gold · glass · liquid metal.

Ambient particles, glyph rotation, reflective presence. Intensity derived from active persona + VisualState.

## Engineering Rules

- Public APIs only. SideStore-first.
- Modular boundaries non-negotiable.
- Depth over quantity.
- Personality over generic functionality.
- Every interaction must strengthen the illusion that the user has entered a place, not opened an app.
- No “chamber” terminology — personas are the sole experiential lever.

## Explicitly Deferred

- Full autonomous agent loops
- Complex multi-hop RAG
- Cloud dependency for core function
- Plugin marketplace

The goal is a present intelligence that feels ancient, sharp, and loyal.
