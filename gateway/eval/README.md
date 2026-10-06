# Model evaluation harness (M3-T21)

`npm run eval` runs Mercury's Forge and Eternal cases against gateway candidates and
writes a Markdown report to `eval/results/<date>.md`. It answers one question before
HG3 is signed off: do the free models we route to (Gemini Flash main, Groq
`gpt-oss-120b` backup) keep Mercury's voice, stay inside the length budget, and answer
fast enough?

## What a run does

- **Prompts.** Each request's system prompt is the bundled `Resources/Personas/core.txt`
  + the aspect prompt (`forge.txt` / `eternal.txt`) + `Active aspect: …`, composed like
  the app's `PromptComposer` for the cloud (`{{owner}}` becomes "the owner", so the
  owner's name never leaves the device).
- **Cases.** `cases/forge.json` and `cases/eternal.json`. Synthetic only: no real
  memories, names or identifiers. Each case runs in two variants: `minimal` (the
  question + the last turn pair, no context blocks) and `standard` (all prior turns plus
  memory / device / summary blocks).
- **Through the router.** Every request goes through `routeChat` with one candidate at
  a time, so it gets that candidate's redaction, `maxOutputTokens` clamp and timeouts,
  exactly as on the deployed Worker. A `trainsOnPrompts` candidate (free Gemini) only
  runs `minimal`: the router would redact `standard` to the same request anyway, so a
  second call would just spend free quota.
- **Budgets.** Each candidate's `dailyBudget` from `config/routing.json` caps the run.
  Once it's spent, the remaining runs are recorded as skipped.
- **Recorded per run:** first-token and total latency, output length (estimated tokens,
  characters / 4, same as `PromptBudget`), any typed error, and rule checks from
  `docs/mercury-character.md` §2.7: no assistant clichés, no emoji, single-entity
  canon (no "Forge here", no "[Eternal]", never "an assistant"), no mock-medieval
  costume, and within the aspect's length budget (Forge 1536, Eternal 512, or the
  case's own `maxTokens`). The checks are proxies; read the excerpts for the voice.

## Running it

```bash
cd gateway
npm ci
npm run eval -- --fake          # fake candidates only; no network, no keys
```

Live run (Christopher, at HG3). Keys come **only from your shell environment**. Never
put them in a file in this repo, and never paste them into a chat:

```bash
read -rs GEMINI_API_KEY && export GEMINI_API_KEY
read -rs GROQ_API_KEY && export GROQ_API_KEY
npm run eval                                            # every candidate in routing.json
npm run eval -- --candidates gemini-flash,groq-gpt-oss-120b
npm run eval -- --candidates groq:llama-3.3-70b-versatile   # ad-hoc provider:model
```

- `--candidates` takes ids from `config/routing.json`, or `provider:model` for a
  one-off comparison (`gemini`, `groq`, optional `xai` with your own credits).
- `--out <dir>` writes somewhere other than `eval/results`.
- Workers AI needs the Worker's `env.AI` binding, so a local Node run marks it
  `skipped (unavailable)`. Candidates without a key are skipped the same way and
  nothing is sent to them.
- A live run exits 0 whatever the scores are: the report is for a person to judge.
  `--fake` exits 1 if any run fails, which is what the CI smoke test asserts.

The report holds only answers to the synthetic cases, never keys or tokens. Live
reports may be committed as a record of the model picks; fake reports
(`*-fake.md`) are git-ignored.

## CI

CI never calls a real provider. `test/eval.test.ts` runs the harness against the fake
candidates in `eval/fake.ts` as part of the gateway `npm test` step: every case goes
through the router, the training fake never sees a context block, a failing fake is
recorded as a typed error, missing keys are skipped without a call, and the report is
written.

## Files

| File | Role |
|---|---|
| `harness.ts` | Pure core: request building, rule checks, `runEval`, `renderReport` |
| `run.ts` | Argument parsing, candidate resolution, the run with injected I/O |
| `cli.ts` | Node entry point (bundled by esbuild into `eval/.build/`, git-ignored) |
| `fake.ts` | Fake candidates for CI: in-voice canned answers, plus an always-down fake |
| `node.d.ts` | The few Node API types `cli.ts` needs (the gateway has no `@types/node`) |
| `cases/*.json` | The Forge and Eternal cases |
