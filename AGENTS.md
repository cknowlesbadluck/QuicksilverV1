# AGENTS.md — Quicksilver / Mercury

## Project
Native iOS intelligence platform. Primary target: iPhone 14 / iOS 27. CI floor: iOS 18.0.

## Non-negotiable Architecture
- Sense (Nexus) → Think (MercuryBrain + Memory + AI) → Express (Personas + UI)
- Core owns all protocols and shared models (SanctumChamber, MemoryItem, etc.)
- MercuryBrain is the only intelligence surface. UI and Intents must prefer the Brain.
- Nexus is persona-agnostic. PersonaID is a tag only.
- DependencyContainer is the composition root.
- Public Apple APIs only. SideStore-first. No private APIs.
- **VisualState is owned by MercuryBrain.** UI only observes.
- **PersonaTheme + MotionTokens** are the only visual/motion sources. No magic numbers in views.

## Master Visual Directive (summary)
Mercury is a **place**, not a dashboard. Quicksilver core is a living entity. Glyphs are instruments. Realms are spatial. See conversation / design directive for full rules. Do not introduce generic AI chat UI patterns.

## Coding Rules
- Prefer Observation, @Observable, actors, structured concurrency, async/await.
- SWIFT_STRICT_CONCURRENCY: complete
- Keep modules small and directional. No upward dependencies into UI or App.
- PersonaTheme drives visual language. Do not hard-code colors per view.
- Every new realm (Forge, Eternal) must route actions through MercuryBrain / NexusCoordinator.

## Agent domain partition (Cursor vs Codex)

### Cursor — strongest at
Multi-file wiring, refactors that touch existing call sites, CI/debug loops, keeping the graph consistent.

**Assign to Cursor:**
1. Wire `RealmGateway` through SanctumView (replace remaining plain sheets for Forge/Eternal).
2. Propagate `brain.visualState` into ForgeViewModel / EternalViewModel / AskViewModel.
3. CHR-6: triage latest Actions logs if Simulator Build still fails; fix destination / concurrency / ModuleCache only.
4. Grep-and-replace remaining `PersonaTheme.spring` → `MotionTokens.spring` / named tokens.
5. Ensure DiagnosticsView / AskView sheets use NavigationStack consistently.

### Codex — strongest at
Greenfield generation of cohesive new files, pure components, docs, and algorithmically clear ViewModels.

**Assign to Codex:**
1. Deepen Forge instruments: `ForgeInstrumentPanel` (build status, experiment log list UI) — Brain-routed only.
2. Deepen Eternal: `MemoryConstellationView` (relationship-oriented memory surface, not a plain List).
3. `InvocationControl` — expandable invoke glyph per directive §14 (idle → expand → listen/think → retract).
4. Unit tests for VisualState transitions on MercuryBrain (thinking → success → idle).
5. ARCHITECTURE.md section: Visual System map (VisualState × Realm × MotionTokens).

### Shared constraints for both
- Do not break SPM tests or Simulator Build.
- Small reviewable commits / PRs.
- No new Core protocols unless required.
- Reduce Motion must keep state communication.

## Vertical Slice Preference
Work one realm at a time. Prefer small, reviewable PRs.
Current priority order: CI green (CHR-6) → visual system integration → Forge (CHR-10) → Eternal (CHR-11) → Quality gate (CHR-12).

## Testing & CI
- SPM unit tests must stay green.
- Simulator Build must pass before merge.
- Archive IPA workflow is the SideStore path.

## Output Discipline
- Complete, paste-ready files preferred.
- Respect existing naming and file layout.
- Do not introduce new Core protocols unless strictly required.
- Humans own the merge decision.
