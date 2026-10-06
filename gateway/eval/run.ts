/**
 * `npm run eval` (M3-T21): argument parsing and the run itself, with all I/O injected so
 * the CI smoke test can drive it without a file system or network. `cli.ts` is the thin
 * Node entry point that supplies real I/O.
 *
 *   npm run eval -- --fake                       # fake candidates only (what CI checks)
 *   npm run eval                                 # every candidate in config/routing.json
 *   npm run eval -- --candidates gemini-flash,groq-gpt-oss-120b
 *   npm run eval -- --candidates groq:llama-3.3-70b-versatile   # ad-hoc provider:model
 *
 * Keys come only from the developer's own environment (`GEMINI_API_KEY`, `GROQ_API_KEY`,
 * optional `XAI_API_KEY`). They are never read from or written to a file here, and never
 * appear in the report. Workers AI needs the Worker's `env.AI` binding, so it is skipped
 * in a local Node run.
 */

import { routingConfig, orderedCandidates, type Candidate, type RoutingConfig } from "../src/limits";
import { envProviders, type ProviderEnv, type ProviderResolver } from "../src/router";
import eternalCases from "./cases/eternal.json";
import forgeCases from "./cases/forge.json";
import { FAKE_CANDIDATES, fakeProviders } from "./fake";
import { passed, renderReport, runEval, type EvalCaseFile, type EvalRun, type PromptSet } from "./harness";

export const SUITES: EvalCaseFile[] = [forgeCases as EvalCaseFile, eternalCases as EvalCaseFile];

/** Prompt files, relative to `gateway/` (npm runs scripts there). */
export const PROMPT_PATHS: Record<keyof PromptSet, string> = {
  core: "../Resources/Personas/core.txt",
  forge: "../Resources/Personas/forge.txt",
  eternal: "../Resources/Personas/eternal.txt",
};

export interface EvalArgs {
  fake: boolean;
  candidates: string[] | null;
  outDir: string;
}

export function parseArgs(argv: readonly string[]): EvalArgs {
  const args: EvalArgs = { fake: false, candidates: null, outDir: "eval/results" };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const value = (name: string) => {
      const next = argv[index + 1];
      if (next === undefined || next.startsWith("--")) throw new Error(`${name} needs a value`);
      index += 1;
      return next;
    };
    if (arg === "--fake") args.fake = true;
    else if (arg === "--candidates") {
      args.candidates = value(arg).split(",").map((id) => id.trim()).filter((id) => id.length > 0);
    } else if (arg === "--out") args.outDir = value(arg);
    else throw new Error(`unknown argument: ${arg}`);
  }
  return args;
}

/** Providers that may train on prompts on their free tier (the router then sends minimal). */
const TRAINING_PROVIDERS = new Set(["gemini"]);
const AD_HOC_PROVIDERS = new Set(["gemini", "groq", "xai", "workersAI"]);

/**
 * Turns `--candidates` into candidates: an id from routing.json, or `provider:model` for
 * an ad-hoc comparison (free-tier Gemini is treated as training, so it gets minimal).
 */
export function resolveCandidates(ids: string[] | null, pool: readonly Candidate[]): Candidate[] {
  if (ids === null) return [...pool];
  return ids.map((id) => {
    const known = pool.find((candidate) => candidate.id === id);
    if (known !== undefined) return known;
    const split = id.indexOf(":");
    const provider = split > 0 ? id.slice(0, split) : "";
    const model = split > 0 ? id.slice(split + 1) : "";
    if (!AD_HOC_PROVIDERS.has(provider) || model.length === 0) {
      throw new Error(`unknown candidate "${id}": use an id from config/routing.json or provider:model`);
    }
    return {
      id,
      provider,
      model,
      displayModel: model,
      trainsOnPrompts: TRAINING_PROVIDERS.has(provider),
      maxOutputTokens: 1536,
      dailyBudget: 20,
      freeDailyRequests: 20,
      freeResetsAtUtcMidnight: false,
    };
  });
}

export interface EvalIO {
  readText(path: string): string;
  writeText(path: string, text: string): void;
  env: ProviderEnv;
  /** Local calendar date, `YYYY-MM-DD`. */
  today: string;
  log(line: string): void;
}

export interface EvalOutcome {
  runs: EvalRun[];
  reportPath: string;
  /** Fake mode fails when any run fails; live runs report and exit 0 for a person to judge. */
  ok: boolean;
}

export async function runFromArgs(
  argv: readonly string[],
  io: EvalIO,
  config: RoutingConfig = routingConfig,
): Promise<EvalOutcome> {
  const args = parseArgs(argv);
  const pool = args.fake ? FAKE_CANDIDATES : orderedCandidates(config);
  const candidates = resolveCandidates(args.candidates, pool);
  const providers: ProviderResolver = args.fake ? fakeProviders : envProviders(io.env);
  const prompts: PromptSet = {
    core: io.readText(PROMPT_PATHS.core),
    forge: io.readText(PROMPT_PATHS.forge),
    eternal: io.readText(PROMPT_PATHS.eternal),
  };

  const runs = await runEval({ config, candidates, suites: SUITES, prompts, providers });
  const mode = args.fake ? "fake (CI smoke)" : "live (developer keys)";
  const reportPath = `${args.outDir}/${args.fake ? `${io.today}-fake` : io.today}.md`;
  io.writeText(reportPath, renderReport(runs, { date: io.today, candidates, mode }));

  const passedCount = runs.filter(passed).length;
  io.log(`eval: ${passedCount}/${runs.length} runs passed; report at gateway/${reportPath}`);
  return { runs, reportPath, ok: !args.fake || passedCount === runs.length };
}
