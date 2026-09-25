# AGENTS.md — Quicksilver / Mercury

## Project
Native iOS intelligence platform. Primary target: iPhone 16e / iOS 27. CI floor: iOS 18.0.

## Non-negotiable Architecture
- Sense (Nexus) → Think (MercuryBrain + Memory + AI) → Express (Quicksilver aspect + UI)
- Core owns all protocols and shared models (MemoryItem, VisualState, etc.)
- MercuryBrain is the only intelligence surface. UI and Intents must prefer the Brain.
- Nexus is persona-agnostic. PersonaID is a tag only.
- DependencyContainer is the composition root.
- Public Apple APIs only. SideStore-first. No private APIs.
- **VisualState is owned by MercuryBrain.** UI only observes.
- **PersonaTheme + MotionTokens** are the only visual/motion sources. No magic numbers in views.
- Quicksilver is one persistent entity. Forge and Eternal are aspects, not separate personas, products, or assistants. An aspect may be pinned per thread as a mood of the one entity; Auto is the default.

## Autonomy Policy
- Owner-authorized multi-step agent loops are permitted.
- Once the owner authorizes autonomy or approves a body of work, the agent may open PRs, update Linear, continue across steps, and propose/execute subsequent vertical slices without requiring a fresh human gate for every micro-decision.
- Residual stop conditions always apply: CI failure, architecture invariant violation, or clear drift from the authorized goal.
- The owner retains the right to revoke autonomy or require a gate at any time. Final merge decisions remain under human control when the owner so chooses.

## Master Visual Directive (summary)
Mercury is a **place**, not a dashboard. Quicksilver core is a living entity. Glyphs are instruments. Realms are spatial. Do not introduce generic AI chat UI patterns.

## Coding Rules
- Prefer Observation, @Observable, actors, structured concurrency, async/await.
- SWIFT_STRICT_CONCURRENCY: complete
- Keep modules small and directional. No upward dependencies into UI or App.
- PersonaTheme drives visual language. Do not hard-code colors per view.
- Every realm (Forge, Eternal) must route actions through MercuryBrain / NexusCoordinator.

## Production Priority
1. CI green (Structure, Lint, SPM tests, Simulator Build)
2. SideStore IPA path reliable
3. Memory-augmented Brain landed
4. Aspect architecture is the only identity model
5. VisualState propagation complete
6. Depth (Forge / Eternal instruments) only after the ship loop is solid

## Vertical Slice Preference
Work one focused production cut at a time. Prefer small, reviewable PRs.
Current focus: CI green → provider verification → SideStore smoke → legacy persona/bridge cleanup → depth.

Audit stabilization pass: September 2026 — single-entity aspect model and entity-wide memory are authoritative.

## Testing & CI
- SPM unit tests must stay green.
- Simulator Build must pass before merge.
- Archive IPA workflow is the SideStore path.

## Output Discipline
- Complete, paste-ready files preferred.
- Respect existing naming and file layout.
- Do not introduce new Core protocols unless strictly required.
