# Mercury prompt drafts

**Docs-only drafts**, the reference for roadmap milestone MP ([../ROADMAP.md](../ROADMAP.md)). They will replace `Resources/Personas/*.txt` in P-T1/P-T2; nothing here is loaded by the app. The character is described in [../mercury-character.md](../mercury-character.md).

| File | Replaces / new | Role | Words | Est. tokens (chars÷4 / cl100k / o200k) |
|---|---|---|---|---|
| `core.txt` | **new** | Shared identity block: controlled chaos, loyalty line, unbreakable rules. Put it before the aspect prompt (P-T1) | 285 | 416 / 383 / 381 |
| `core-compact.txt` | **new (optional)** | Short core for Apple Foundation Models / small-context turns (P-T4) | 112 | 158 / 154 / 152 |
| `quicksilver.txt` | replaces `Resources/Personas/quicksilver.txt` | Open (default) aspect: witty, snarky, vain | 169 | 229 / 211 / 211 |
| `forge.txt` | replaces `Resources/Personas/forge.txt` | Forge aspect: erratic brilliance that lands on a crisp answer | 168 | 256 / 234 / 231 |
| `eternal.txt` | replaces `Resources/Personas/eternal.txt` | Eternal aspect: ancient, aloof, sparing; exact recall | 163 | 240 / 224 / 222 |

Budgets enforced by P-T3: aspect ≤ 260 · core ≤ 420 · compact ≤ 160 (chars÷4). All v2 drafts pass. Budget against **chars÷4**, the repo's own heuristic (`BrainComposition.estimateContextTokens`); Apple's on-device tokenizer isn't public, and chars÷4 is the most pessimistic of the three counts.

## Composed budgets (system prompt only, before memory and device lines)

| Path | Composition | ≈ tokens (chars÷4) |
|---|---|---|
| Cloud (Grok / Gemini) | core + aspect | 645–672 |
| On-device (Foundation Models, 4,096-token window shared by prompt and reply) | core-compact + aspect | 387–414 |
| Today, if only the aspect files are swapped (no composition yet) | aspect alone | 229–256 |

`BrainComposition.systemPrompt` currently also appends a hard-coded "Core stance" block (about 110 tokens, and it includes "Critique ideas, never the person", which now contradicts the direction). `PersonalityState.promptBias()` adds up to about 120 more. P-T1 removes the Core stance and P-T18 rewrites the bias clauses.

## Design notes
- **Every aspect file works on its own.** Each one opens with "You are Mercury, in your X aspect" and ends with a one-line truth-and-safety guard. So you can swap the files before the core composition lands without losing identity or safety. Once the core is composed, the duplicated guard costs about 25 tokens, which is worth keeping.
- **Single entity.** No file says "You are Forge" or "You are Eternal". Aspects are "moods" or "aspects of you". This matches AGENTS.md: "Forge and Eternal are aspects, not selectable personas".
- **No IP.** The current `quicksilver.txt` says "Think Loki". The drafts remove it on purpose: naming the character invites a large cloud model to quote the films. The archetype is described through Mercury/Hermes and quicksilver instead.
- **v2 (controlled chaos + affectionate mockery).** Theme: a chaotic, unpredictable surface over a core that is always precise and in control. The open aspect is snarky and vain; Forge is erratic and brilliant (the chaos comes from style instructions, not a higher temperature); Eternal is ancient, aloof and sparing. Mercury **may mock Christopher himself**, affectionately. The core carries an explicit loyalty line ("unquestionably on Christopher's side… never undermine, deceive or work against him").
- **Rule changes vs v1.** The only edit to the Unbreakable block is that "critique ideas, never the person" was cut to "Challenge wrong ideas precisely and with style", per the new direction. The truth, invention, mask-slip and refusal lines are byte-identical to v1.
- **Small-model friendly.** Short imperative bullets, no nested conditions, no persona tables, concrete banned phrases. Small models follow explicit lists better than abstract descriptions.
- **Owner name.** "Christopher" is hard-coded because this is a single-owner app. If it ever ships to others, template it (for example `{{owner}}`) in PromptManager.
- **Temperatures (P-T18):** open 0.7 (unchanged), Forge 0.3 → **0.45** (livelier phrasing, still reliable for code), Eternal 0.4 → **0.35**. Forge's chaos is written into the style instructions (bursts, tangents, self-interruptions, then a snap to one recommendation) rather than coming from sampling randomness, so answers stay correct.
