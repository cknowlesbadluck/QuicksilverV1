# Mercury: Visual & Interaction Direction (v2, "capable first")

*For cknowlesbadluck/QuicksilverV1. Builds on the character bible [mercury-character.md](mercury-character.md) (controlled chaos) and milestone MP (P-T1..P-T18). The PR-sized tasks are milestone **MV** (V-T1..V-T23) in [ROADMAP.md](ROADMAP.md); this doc is the design reference.*

> **Owner direction (2026-09-25):** "Don't make it a game. Just a distinct and capable AI assistant. Basically ChatGPT, Siri and Loki combined."
> v1 of this doc (touch-to-play physics, poke reactions, tilt sloshing, drag-to-travel) is **withdrawn**. None of it ships.

---

## 1. The vision

Mercury is the assistant you reach for first because it is fast, clear, and always within a thumb's reach, and it happens to have a personality. Answers arrive as a clean, well-set document: headings, lists, code you can copy, sources, and result cards you can act on, streaming in and stoppable at any moment. You can reach him from anywhere: the Action button, Siri, Spotlight, Shortcuts, a Control Center control, the share sheet. The liquid-metal presence at the top of the screen is not a toy. It is a face. It shows whether he's listening, thinking, speaking, or being serious, and which mood (aspect) he's in, through small, precise changes in motion, colour and haptics. The chaos lives in the character and in a few short moments (the reveal, the thinking, a shift of aspect). Everything you read and tap is calm, legible, and exact.

**ChatGPT** gives the answer quality and surface: rich formatting, threads, follow-ups, copy/share, stop.
**Siri** gives the reach: voice, system entry points, glanceable, hands-free.
**Loki** gives the character: the wit, the presence, the mask that slips when it matters.

---

## 2. Design principles

1. **Capability before theatre.** Every screen answers "what can I do here, quickly?" first. No animation delays a result. Time to first token on screen is never held back for a choreography beat longer than the P-T7 holds (400 ms open/Forge, 900 ms Eternal), and text starts rendering while the presence is still settling.
2. **Calm surface, living face.** Text, controls and layout are still and precise. Only the presence (the core) moves continuously, and only as much as its state needs. Chaos is a *moment*, never an ambience.
3. **A document, not a chat.** Mercury's answers are full-width, typographically set documents. Your words appear as a quiet margin line above them. No bubbles, no avatars, no alternating left/right (AGENTS.md: no generic chat UI).
4. **Every state is visible, every action is one step.** Listening, thinking, speaking, stopped, offline/on-device, serious: always readable at a glance. Stop, copy, share, remember, follow up: always one tap away.
5. **Honest when it matters.** Warnings, errors, destructive and privacy moments drop all chaos and all jokes (bible §4, §7.5). The mask slip (`.steady`) turns everything warm silver and still.
6. **Metal, not glass.** Mercury is opaque, reflective, heavy liquid metal. Apple's Liquid Glass is translucent and deferential. They coexist: system chrome stays Liquid Glass; Mercury never goes glassy, and glass never sits *on* Mercury.
7. **Cheap by default.** At most one continuously animating element per screen, 30 fps when idle, paused when you can't see it. The iPhone 16e is a 60 Hz panel with no ProMotion, so the whole budget is built for 60 Hz.

---

## 3. Signature moments (capability × character)

These five moments are what make Mercury recognisable. They are moments, not gestures.

| # | Moment | What you experience | Capability | Character |
|---|---|---|---|---|
| 1 | **Summoned from anywhere** | Press the Action button (or Control, Siri, widget, Spotlight). Mercury opens *already listening*, the core gathers from a still puddle into a bead with one quick silver snap, and a time-aware line appears ("It's late. I'm judging. Quietly."). | Zero-tap voice entry; the Action button works with an App Shortcut, so no extension is needed. | The entrance is his: sly, quick, a little smug. |
| 2 | **The inscription** | The answer streams in as a clean document. The headline or recommendation appears first and biggest. Code blocks have Copy; sources are chips; tool results are cards. A Stop control sits where the send button was. | ChatGPT-grade answer surface: markdown blocks, code, lists, tables, sources, cards, stop, copy, share, select. | Per-aspect entrance: open *flicks* in crisply, Forge's headline *scrambles and snaps* into place, Eternal *fades in slowly like starlight*. Only the first block performs; the rest just appear. |
| 3 | **Shift, then snap** | Ask a build question and a small chip appears by the core: "Forge · this is a build problem". The core heats from silver to molten green, jitters while it thinks, then snaps to a crisp lattice as the answer lands with one clean tap. Tap the chip to pin or undo. | Aspects shift automatically with a *visible reason*, and you can pin one for a thread (Auto / Quicksilver / Forge / Eternal). | Controlled chaos in one second: chaos, then a precise landing (bible §5.6). |
| 4 | **Receipts** | When Mercury uses a memory, the answer shows a small citation chip: "From your note, Tue 15th". Tap it and the memory opens in the Archive, where you can edit or forget it. | Memory you can see, verify and fix. Threads and memories are searchable, and optionally show up in Spotlight. | Eternal's exact recall ("So it was decided. Tuesday."), made trustworthy. |
| 5 | **The mask slip** | You say something heavy. The core stops moving, colours settle to warm hearth silver, haptics go silent, and the words turn plain. | Safety, and trust in an assistant with an edge. | The stillness *is* the signal: someone is paying attention (bible §4.3). |

---

## 4. Interaction vocabulary

All gestures are standard iOS. There's no hidden or playful gesture. Each one has a visible control and an accessibility equivalent. Semantic events go to the Brain as `InteractionEvent` (V-T1); the finger position, mic level and scroll never leave the UI.

| Action | How | What happens | Per-aspect expression | Haptic (P-T11 + V-T12) | Accessible equivalent |
|---|---|---|---|---|---|
| **Invoke** | Tap the composer; tap the presence; Action button; Control; Siri "Ask Mercury"; widget; Spotlight; `mercury://listen` | Invocation opens, keyboard or mic ready | Open: quick snap. Forge: brief ember flare. Eternal: slow brighten. Mask slip: none | none (listening start only if voice) | Presence is a button: "Ask Mercury"; Siri/Shortcuts |
| **Speak** | Hold the mic in the composer (hold-to-talk), or tap once for hands-free mode, which ends on a pause; Siri | Listening state; live transcript shown in the composer; release sends; slide left to cancel | Core rim pulses gently with *real mic level* (the only input-driven motion) | soft tick on start, one on stop | Mic is a toggle button ("Start dictation" / "Stop and send"); Voice Control "Tap Speak" |
| **Interrupt** | Tap Stop (replaces Send while busy); start speaking or send a new message while he's answering (barge-in) | Stream cancelled (M3-T1); the partial answer is kept and marked "stopped" | Forge: sparks die instantly; others: settle | one crisp tap | Stop button; VoiceOver Magic Tap (two-finger double-tap) stops/starts |
| **Follow up** | Type in the docked composer; tap a suggestion chip; "Ask about this" on any block | Sent on the same thread with context (M3-T8/T9) | normal thinking per aspect | light tick on send (none in mask slip) | All are buttons; the block action is in the rotor/Actions |
| **Switch aspect deliberately** | Tap the aspect chip next to the core → menu: Auto (default), Quicksilver, Forge, Eternal. Pin lasts for the thread. Or ask ("be Forge about this") | Brain records the pin; the chip shows "Forge · pinned" | restrained morph (≤ 450 ms; Eternal 1.2 s) | none | Chip is a menu button; also an App Intent "Set Mercury's aspect" |
| **Auto shift (Mercury decides)** | none (Brain / AspectPolicy) | Chip shows the aspect *and reason* for 4 s, then collapses to a dot. Tap within 4 s to undo | same morph | none | VoiceOver announcement "Forge, for a build problem" (polite, once) |
| **Revisit** | Threads list (search, pins); memory citation chips; Archive (search, timeline); Spotlight | Opens the thread or memory in place | Archive/Eternal: calm starfield backdrop, no motion on content | none | Standard lists and search, and a rotor over the list |
| **Act on a result** | Long-press any block, or tap its trailing ••• → Copy, Share, Remember, Ask about this, Open source; code: Copy code; cards: their action button | Performs via Brain action registry (M3.5-T20) where it changes state | Remember: the block's rim glints once | Remember/action done: one soft tap. Copy/share: none | Every action is in the Actions rotor and the ••• button |
| **Touch acknowledgement** | Tap the presence | Opens Invocation (same as invoke) with one soft brightness ripple | per-aspect tint of the ripple | none | as Invoke |
| **Dismiss** | Swipe down on the sheet; Done | Back to the Sanctum; the thread is kept | none | none | Escape gesture (two-finger Z); Done button |

**Explicitly not in the vocabulary:** poke/tease reactions, "fighting back", drag-to-travel, pinch-to-switch aspect, tilt/slosh, shake. See §10.

---

## 5. Per-screen concepts

### 5.1 Sanctum (home): a command centre with a face
- **Top third:** the presence (core, ~88 pt) with the aspect chip and a one-line living status ("The Sanctum holds. I'm listening."). The greeting is chosen by time of day and absence (P-T14, V-T15).
- **Middle:** "Continue": the last thread's title and first line (tap to resume), then at most one insight from Nexus as a quiet card and two or three suggestions ("Summarise yesterday", "What's hot on the phone?").
- **Bottom:** the **composer dock** (field + mic), always present, the same component as in Invocation. Typing here opens Invocation with the text carried over.
- **Places row:** Workshop, Observatory, Archive, Codex, Diagnostics as a compact, labelled row of etched icons (SF Symbols with `.drawOn` on appear, iOS 26+). The decorative orbit ring and portal halos are removed, as are the debug-looking `SANCTUM · IDLE` label and the `bubble.left` chat icon.
- **Idle:** the core breathes (P-T12 idle life, subtle). After 10 min it sleeps into a flat still puddle; on return it gathers back up.

### 5.2 Invocation (Ask): the inscription
- Replaces `AskView`, building on M5-T12/T13. **Proposed change to M5-T12:** show the *current thread* as a scrollable document (every exchange), not only the latest exchange. ChatGPT-level usability needs scrollback. "Echoes" becomes the Threads list.
- **Each exchange:** your prompt as a small silver margin line with a thin left rule (not a bubble), then Mercury's answer as a full-width document. It's rendered from `AnswerDocument` blocks (V-T4/V-T5): headings, paragraphs with inline markdown, lists, tables, quotes, code (mono, horizontal scroll, Copy), source chips, memory citation chips, action/result cards, images when a provider returns them.
- **Footer per answer:** a subtle source glyph (on-device droplet vs cloud droplet-with-thread; M5-T13), Copy, Share, Remember, Regenerate, and 0–3 follow-up chips (on-device generated when available).
- **Presence:** shrinks to 44 pt in the navigation bar area while scrolling, and still shows the state. While thinking, it is the only moving thing.
- **Composer:** docked; multiline; the mic is hold-to-talk or tap for hands-free; Send becomes Stop while busy; paste and (later) attach. Writing Tools `.limited` (M3.5-T18).
- **Streaming:** the newest block renders progressively. Only the *first* block of each answer gets the per-aspect entrance; everything after appears as it streams, with no per-glyph animation on long text.

### 5.3 Forge (Workshop): the workbench
- Purpose: engineering and making. Same composer and inscription as Invocation, plus an **"Attach context"** tray: session notes and live instrument readings (thermal, memory, storage, network) as chips you toggle on. They're sent through the Brain as structured context, never directly to a provider.
- **Answer shape:** Forge answers render the **recommendation card first** (bold, lattice-edged, with a Copy action), then steps and code. This is the visual form of "chaos, then one crisp recommendation".
- **Thinking:** the core jitters, throws a few sparks and surges, then snaps (P-T13). The instrument tiles stay perfectly still.
- Backdrop: banked embers at low opacity; paused under Reduce Motion or Low Power.

### 5.4 Eternal (Observatory) and Archive: memory you can find
- **Archive** is the source of truth: a searchable timeline of memories (notes, distilled memories) and a Threads tab. Filter chips (Notes · Distilled · Threads · Pinned), swipe to forget (plain confirmation copy), tap to edit.
- **Observatory** is the Eternal view of the same data: a calm, slow starfield backdrop, a "Long view" summary card (on-device summary, M3.5-T21), "On this day", and the reflective composer. A small, optional **constellation header** shows the last 30 days of memories as stars (brightness = importance). It's decorative and tappable (opens the list filtered to that day), never the only way in.
- Near-still: 240 s orbit, one drifting star about every 45 s (P-T12).

### 5.5 Diagnostics (Nexus): honest instruments
- A plain, dense, readable list of signals and insights, each with a one-line Mercury voice summary and the plain detail (P-T15 pattern).
- **No chaos at all** on this screen. The health score is a number plus a still bar. Warnings use `.warning` once per incident. "Run diagnosis" hands off to Forge with the readings pre-attached.

### 5.6 Codex (settings): the rules, etched
- Standard `Form` with system Liquid Glass chrome. Sections: Intelligence (gateway/keys, on-device status), Voice (hands-free, read replies aloud [optional V-T18], haptics on/off), Privacy (Spotlight toggles, crash reporting), Appearance (reduce Mercury motion, independent of the system setting), About.
- Destructive and privacy copy is plain. There's one quip, in the header only ("Ah. The rules. Everyone's favourite.").

### 5.7 First launch
Three short, skippable steps, about 20 seconds in total:
1. **Wake:** a single drop settles into the bead (1.2 s; appears instantly under Reduce Motion). "Oh. Someone's here."
2. **Intelligence:** on-device status (and why if unavailable) plus bind the gateway (M3-T6), or "Later".
3. **Reach:** "Put me on your Action button" (deep link to Settings › Action Button, with the App Shortcut already there), and the Siri phrase.

After that, the Sanctum. The tips don't come back.

---

## 6. Aspect transitions (restrained)

The aspect is a continuous blend, `AspectBlend` (three weights), driven by one spring. The presence renderer interpolates P-T8 `ExpressionProfile` and P-T10 `ColorTemperament` values. Only the **core and its chip** morph. The screen's layout, text and controls never change with aspect, apart from the accent tint of the aspect chip and the source glyph.

| From → to | Choreography | Duration |
|---|---|---|
| Open → Forge | the silver warms to white-hot, then to molten green; a 120 ms jitter, then the lattice snap | ≤ 450 ms |
| Open → Eternal | cools and darkens to dim violet; the bloom contracts; a few stars fade in behind the core | 1.2 s |
| Forge → Eternal | sparks go out one by one, then it cools | 1.2 s |
| Eternal / Forge → Open | the core liquefies back to silver with one highlight flick (the smirk) | 450 ms |
| Any → `.steady` (mask slip) | all chaos stops; colour goes to `hearthSilver` (`maskSlipSettle`, 0.9 s, critically damped) | 0.9 s |
| Reduce Motion | cross-fade of colour only, 250 ms; no jitter or sparks | 250 ms |

Auto shifts show the reason chip. Pinned shifts show "· pinned". In `.steady` the pin is recorded but the calm look wins until the register returns to playful (P-T5 latch).

---

## 7. System surfaces (Siri-level reach)

The iPhone 16e has a **notch, not a Dynamic Island**, a **60 Hz** display, an **Action button**, and **no Camera Control** (Apple tech specs). So the design leans on the Action button, Siri, Shortcuts and the Lock Screen, not the Dynamic Island.

| Surface | Extension needed? | Design | Task |
|---|---|---|---|
| **Action button** | No (App Shortcut) | "Talk to Mercury" opens the app straight into listening | V-T16 |
| **Siri / Shortcuts / Spotlight actions** | No | Ask Mercury (text/voice) with a Mercury-styled answer snippet: a static bead, the first 3 blocks of the `AnswerDocument` lite render, and an "Open in Mercury" button. No bubble. | V-T16 extends M3.5-T16/T17 |
| **Share sheet** | No (via Shortcuts) | "Ask Mercury about this" accepts shared text/URLs through the App Intent's text parameter. A true Share Extension is deferred (App ID cost) | V-T16 |
| **Spotlight** | No | Memories (M3.5-T13). Thread *titles* optional and **off by default** (owner decision; M3.5-T13 says chat is never exposed) | V-T9 |
| **Home/Lock Screen widget** | Yes | Small: bead in the current aspect/state plus the greeting. Medium: plus the last thread and [Talk] [Ask] buttons (`Button(intent:)`). Lock accessory: droplet glyph that opens listening. Static renders, no animation. | V-T21 (optional) |
| **Control Center / Lock Screen control** | Yes (same extension) | "Talk to Mercury" `ControlWidget`, which can also be put on the Action button | V-T21 (optional) |
| **Live Activity** | Yes (same extension) | Only for long work you leave (a long cloud answer or a Forge diagnosis): Lock Screen shows the state and the first line when ready. On 16e it's Lock Screen/StandBy only | V-T22 (optional) |

**SideStore cost:** every app extension uses an extra App ID (free accounts get 10 App IDs per 7 days and 3 active apps). Newer SideStore builds can sign extensions with the main app's profile. That's why the widget, control and Live Activity live in **one** extension, are optional, and are gated on an owner decision (Q-V1).

---

## 8. Technical approach

### 8.1 Architecture (Sense → Think → Express)
- **Core** (SPM-tested, no protocols added): `InteractionEvent` (V-T1) holds the semantic events above. `InteractionPolicy` is a pure event × context → response mapping: next state, route, haptic moment, presence cue. `RenderTierPolicy` (V-T3), `AnswerDocument` + `AnswerParser` (V-T4), `AspectPin` (V-T2). The V-T1/V-T2/V-T4 types were prototyped and type-checked under Swift 6.2 strict concurrency before this plan was written.
- **MercuryBrain** (App) gets one entry point, `handle(_ event: InteractionEvent)`. It stays the only writer of `VisualState`, the active aspect, the pin, and a new Brain-owned `presenceCue`/`aspectShiftReason`. It's a synchronous main-actor call rather than a stream: gestures are already on the main actor, and an async hop would add a frame of latency. Streaming answers flow Brain → view model as `AnswerDocument` snapshots.
- **UI** renders only. Continuous inputs (mic level, scroll offset) stay local. All numbers come from `PersonaTheme`/`MotionTokens` (moving to `DesignTokens/` in M3.5-T23), which are tested by AppTests (M2-T1).

### 8.2 Rendering the presence
- **Tier `.shader`:** the existing Canvas bead path, with one Metal `layerEffect` for metallic shading (normal from the alpha gradient, fake environment reflection, specular) and a `colorEffect` for heat (Forge) and cool (Eternal). The shader is precompiled with `Shader.compile(as:)` (iOS 18) when the Sanctum appears, so the first frame doesn't hitch. `maxSampleOffset` is 2 pt, and the shader is applied only to the core's frame (at most ~260 × 260 pt), never full screen.
- **Tier `.canvas`:** today's `MercuryFluidSurface` Canvas path with gradient shading, no shader. Used in Low Power Mode, at serious thermal state, or if shader compile fails.
- **Tier `.still`:** a static rendered bead with state shown by colour, brightness and the chip only. Used under Reduce Motion, at critical thermal state, or when the scene is inactive.
- **One clock per screen:** `MercuryClock`, a single `TimelineView` governed by M5-T7's `AnimationCadence`. It replaces the 3–4 separate timelines now in the Sanctum (AmbientLayer 30 fps, fluid surface 30 fps, chaos field 24 fps with `paused: false`).
- **Metal can't be compiled on this box.** The `.metal` file sits in `UI/Render/` (app target). The CI *iOS Simulator Build* compiles it via xcodebuild (`CompileMetalFile` in the log), and that's the acceptance evidence.

### 8.3 The answer surface
- `AnswerParser` is a pure, streaming-safe block parser: headings, paragraphs, lists, code fences (an unterminated fence stays code), quotes, and tables later. It reparses the accumulated text per delta, which is cheap at answer sizes. Inline styling uses `AttributedString(markdown:, options: .inlineOnlyPreservingWhitespace)`. There's **no third-party markdown dependency**.
- The first-block entrance uses a SwiftUI `TextRenderer` (iOS 18), with per-aspect `ForgedTextRenderer` effects that animate at most the first 80 glyphs. Everything else is plain `Text` with `.textSelection(.enabled)`.
- Code blocks use SF Mono with a horizontal `ScrollView` and Copy. There's no syntax highlighter in v1 (a small keyword tint is optional later).
- Result cards (`remember`, `status`, `enterAspect`, `openDiagnostics`) map from M3.5-T20 `MercuryAction` results.

### 8.4 Motion, haptics, voice
- **Motion vocabulary:** P-T9 (`snapToForm`, `smirkFlick`, `feint`, `slowReveal`, `maskSlipSettle`…). V tasks add only `inscriptionEntrance(aspect)`, `aspectMorph(from:to:)` and `presenceCollapse` to MotionTokens.
- **Haptics:** P-T11 owns `HapticCue`. V-T12 adds five productivity moments (listenStart, listenStop, sent, stopped, actionDone) under the same "one haptic per user action" budget, plus a Codex toggle. Forge answer landing = P-T11 burst → tap. Eternal stays near-silent.
- **Voice in:** M3.5-T22 (on-device). The presence rim follows the real mic RMS level, sampled at 30 Hz from the audio tap, and that's all.
- **Voice out (optional, V-T18):** `AVSpeechSynthesizer`, on-device and free, off by default. The bible's "no sound" rule is about sound effects; reading answers aloud is a capability, approved as an opt-in setting (Q-V2).

### 8.5 Performance budget (iPhone 16e, A18, 60 Hz)
| Budget | Target |
|---|---|
| Frame | 16.7 ms. Main thread ≤ 6 ms/frame during streaming; GPU ≤ 6 ms for the presence |
| Animated elements | ≤ 1 continuous timeline per screen; ≤ 80 animated glyphs at once |
| Cadence (M5-T7) | idle 30 fps; thinking/entrance/morph 60 fps; Low Power 15 fps (tier `.canvas`); hidden or inactive: paused |
| Streaming | UI updates coalesced to ≤ 20 per second (batch deltas) so SwiftUI invalidates the document at most 20×/s |
| Energy | Sanctum idle in the foreground rates "Low" on the Xcode energy gauge; 20 min foreground soak no worse than today's build (HG7/HG-V) |
| First-use hitch | shaders precompiled; the haptic engine starts lazily with auto-shutdown |

**Harness (V-T3):** `OSSignposter` intervals around presence frames and document updates; a DEBUG-only on-screen HUD (launch arg `-mercuryPerfHUD`) showing fps and worst frame time; an XCUITest that streams a fake 4,000-char answer and records `XCTClockMetric` / hitch signposts on the simulator. The simulator only *trends* performance; **the phone is the gate** (HG-V).

Note: `AspectPolicy` moves Mercury to **Forge** in Low Power Mode, and Forge is the most animated aspect. The tier policy wins: in Low Power Mode, Forge renders as a "banked fire" (tier `.canvas`, 15 fps, no sparks).

---

## 9. Accessibility

- **VoiceOver:** each answer block is one element, and the whole answer can be read with one swipe via the rotor. State changes are announced politely and at most once ("Thinking", "Answer ready", "Forge, for a build problem"). Magic Tap starts or stops dictation and stops streaming. Every block action is in the Actions rotor.
- **Every control is visible:** there's no gesture-only function. Hold-to-talk has a tap-toggle alternative. Long-press menus duplicate the ••• button.
- **Reduce Motion:** the presence goes to tier `.still`; entrances become a 150 ms fade; morphs become a colour cross-fade; the chaos is removed and the resolution kept (bible rule). There's also an in-app "Reduce Mercury motion" switch.
- **Reduce Transparency:** blooms and glows become solid; no translucent panels (etched opaque panels, V-T14). **Increase Contrast:** silver text on void ≥ 7:1, thicker hairlines.
- **Dynamic Type:** all text styles scale, including code; the layout reflows up to AX5; the presence shrinks first.
- **Photosensitivity:** Forge flicker ≤ 10% brightness, only on the ~88 pt core, never more than 3 flashes/s at high contrast (WCAG 2.3.1).
- **Haptics:** a Codex toggle; nothing important is ever conveyed by haptics alone.
- CI: `performAccessibilityAudit()` on Sanctum, Invocation, Forge, Observatory, Archive, Codex and Diagnostics (M5-T10/T11 plus V-T20).

---

## 10. Explicitly NOT doing

- **No game mechanics:** no poke/tease reactions, "pushing back" when touched, drag-to-travel, pinch-to-switch aspect, tilt/slosh physics, shake, or touch-deformable metal.
- **No tilt parallax.** It was judged not worth its Core Motion cost and distraction on a 60 Hz phone. Dropped.
- **No chat bubbles, avatars or typing dots.** No spinners in Mercury's presence (P-T13).
- **No aspect "persona picker" as a product.** The pin is a mood for this thread on one entity; Auto is the default.
- **No 3D engines** (SceneKit/RealityKit/Unity), **no ARKit, no camera "noticing you"**, no sound effects, no custom fonts, no paid assets, **no third-party SDKs** (no Rive, Lottie or markdown libraries).
- **No Liquid Glass on Mercury**, and no custom blur materials replacing system glass.
- **No Dynamic Island-first design** (the 16e has none), and no animated widgets.
- **No iOS 27-only APIs** until CI runs Xcode 27 (roadmap risk 1). The deployment floor stays iOS 18. iOS 26 features (SF Symbols Draw, Liquid Glass, interactive snippets) sit behind `#available`.
- **Mobbin reference research was not possible** (the Mobbin MCP needs a paid plan). **No concept images** (no image tool available here).

## 11. Owner decisions and open question
Decided 2026-09-25 under the creative control Christopher granted (recorded as Owner decision 10 in [ROADMAP.md](ROADMAP.md)):
- **Q-V2 → yes:** optional "read replies aloud" (V-T18), on-device TTS, an opt-in Codex setting that is **off by default**.
- **Q-V3 → yes:** aspects may be **pinned per thread** as a mood of the one entity; Auto is the default. AGENTS.md is reworded to match. The mask slip still overrides a pin.
- **Q-V4 → yes:** M5-T12 shows the **scrollable current thread**, not only the current exchange.
- **Q-V5 → yes, off by default:** thread titles may be indexed in Spotlight (titles only), behind a Codex toggle that defaults off.

Still open (ask Christopher when V-T21 is reached):
- **Q-V1:** accept one app extension (widget + control + Live Activity) at the cost of one extra SideStore App ID? Default: not before 1.0.
