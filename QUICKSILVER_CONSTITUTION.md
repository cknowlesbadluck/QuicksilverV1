# Quicksilver Constitution

Permanent product rules for QuicksilverV1. Revise only by explicit product decision.

Observed against `main` `aa12cc58` on 2026-09-29. This file freezes identity. It does not claim the implementation already satisfies every rule.

## What this is

QuicksilverV1 is a native iOS intelligence environment inhabited by one continuous entity: Quicksilver.

It is not:

- a chat transcript with a theme
- a persona dropdown
- a model selector
- a themed chatbot
- a Resonance client
- a Conduit terminal

It is defined by continuous identity, persistent memory, autonomous aspect manifestation, spatial environments, tool use, contextual behavior, intelligent routing, and native iOS integration.

## Terminology

| Term | Meaning |
| --- | --- |
| Quicksilver | The project and the bonded intelligence. Primary surface aspect. |
| Mercury | Quicksilver's title, not its everyday name. |
| MercuryBrain | The only intelligence coordinator. UI and Intents talk to the Brain. |
| Forge | Aspect for engineering, creation, invention, debugging, architecture. |
| Eternal | Aspect for orchestration, automation, planning, systems work. |
| Aspect | A manifestation of one entity. Never a mode, product, or selectable persona. |
| Sanctum | Default spatial environment. Quicksilver's place. |
| Workshop | Forge's domain. Must do engineering work, not reskin chat. |
| Observatory | Eternal's domain. Must show real system state. |
| Archive | Physical representation of memory, history, knowledge, configuration. |

## Identity rules

1. Quicksilver is both the project and the bonded intelligence.
2. Mercury is the title, not the normal spoken name.
3. Quicksilver, Forge, and Eternal are aspects of one entity.
4. They are not selectable personas or modes.
5. The user never manually selects an aspect.
6. All aspects share one continuous identity and memory.
7. The AI model provider must not decide which aspect appears.
8. One provider may serve multiple aspects.
9. An aspect may use different providers at different times.
10. The Brain chooses the active aspect from context. The user cannot pin it.

## Product boundaries

1. Native iOS-first. Swift and SwiftUI are the primary implementation technologies.
2. Prefer Apple-native frameworks where practical.
3. QuicksilverV1 remains independent from Resonance. Domain independence is non-negotiable.
4. Conduit may extend Quicksilver but must not be required for basic operation.
5. Personal use, not mass distribution. No App Store requirement for V1.
6. Prefer free infrastructure and free-tier capabilities where realistic.
7. Security, resilience, and maintainability rank with visual ambition.
8. Public Apple APIs only. SideStore-first install path.

## Architecture rules

```
User / Voice / App Intent
        ↓
  MercuryBrain
        ↓
 Context + Memory + Intent
        ↓
    Model Router
        ↓
   Tool Execution
        ↓
 Native iOS | Conduit (optional) | External
```

Spatial map:

```
              OBSERVATORY (Eternal)
                     |
ARCHIVE ─── SANCTUM ─── WORKSHOP
 Memory     Quicksilver         Forge
                     |
               MercuryBrain
```

- Core owns protocols and shared models. Other modules depend on Core, never the reverse.
- Sense (Nexus) → Think (Brain + Memory + AI) → Express (aspect + UI).
- UI only presents. UI does not own prompts, routing, memory writes, or tool authorization.
- VisualState is owned by MercuryBrain. UI observes.
- PersonaTheme + MotionTokens are the only visual and motion sources.
- Deterministic application logic owns state, authorization, memory rules, aspect dwell, provider fallback, navigation permission, tool validation, and security.
- Models own reasoning, synthesis, language, planning, and interpretation.
- The app must run end-to-end with a mock intelligence provider.

## Interaction philosophy

- The interface is spatial, environmental, dimensional, and alive.
- It must not primarily feel like a tabbed chat application.
- Visual direction: controlled chaos, corrupted Norse influence, quicksilver, dark dimensional space, wraithlike manifestation.
- Branding is not the product. If colors and fonts are stripped, Sanctum must still not look like a generic AI client.
- Aspect changes may affect language, environment, manifestation, contextual controls, tool priority, density, and transition. They must not hard-bind a provider.

## Provider independence

Providers are adapters. Preferred → secondary → reduced local capability.

Quicksilver remains usable when any single provider, or Conduit, is unavailable.

## Infrastructure constraints

- No committed secrets.
- Credentials in Keychain.
- HTTPS with certificate validation.
- Destructive tools require confirmation.
- Persistence must survive relaunch and survive failed migrations without silent data loss.

## Personal-use assumptions

- One owner. One primary device (current target: iPhone, SideStore sideload).
- No multi-user accounts, subscriptions, or public web product in V1.
- Device soak testing is part of the definition of done.

## Exit test for this constitution

Any developer or agent working in this repository must answer, without citing colors, fonts, slogans, or prompt text:

> What makes QuicksilverV1 fundamentally different from a themed AI chatbot?

Required answer shape:

It is one continuous native intelligence with automatic aspects, persistent memory, a coordinator that is not the model, spatial domains that do real work, optional Conduit, and independence from Resonance.

## Current implementation debt against this constitution

These are facts as of 2026-09-29, not future work disguised as shipped capability:

- `QUICKSILVER_CONSTITUTION.md` did not exist on `main` before this file.
- Folder names still say `Personas`. That is historical naming. Aspects are the product model.
- Open PR `#193` (fix for `#191` injectable container + cosmological Sanctum) has green Structure/Lint/SPM and **failed iOS Simulator Build**. Do not merge until Simulator Build is green.
- Open PR `#191` is the unfixed predecessor. Prefer `#193`.
- Hygiene docs PR `#187` is stale against current `main`.
- Conduit is optional and live at `https://conduit-feco.onrender.com/mcp` (health 200). Quicksilver must not hard-depend on it.
- Resonance is a separate product. Do not import Resonance types into Quicksilver Core.
