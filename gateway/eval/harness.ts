/**
 * Model evaluation harness (M3-T21). Runs the Forge and Eternal cases against chosen
 * candidates **through the router** (`routeChat`), one candidate at a time, so each run
 * gets that candidate's per-candidate redaction, `maxOutputTokens` clamp and timeouts,
 * exactly as the deployed gateway would apply them.
 *
 * It records first-token and total latency, output length, errors and rule checks
 * (docs/mercury-character.md §2.7: no assistant clichés, no emoji, single-entity canon,
 * no mock-medieval costume, within the aspect's length budget) and renders a Markdown
 * report. The checks are cheap proxies; the report keeps an excerpt of every answer so
 * a person judges the voice itself.
 *
 * Pure: no file system, no process, no network of its own. `run.ts` wires I/O, and the
 * CI smoke test (test/eval.test.ts) runs it against the fake provider only.
 */

import { DailyBudgets, type Candidate, type RoutingConfig } from "../src/limits";
import { contextLevel, routeChat, type ContextLevel, type ProviderResolver } from "../src/router";
import type { ChatRequestV1, ContextKind, ErrorCode, Privacy } from "../src/stream";

// MARK: - Cases and prompts

export type EvalAspect = "forge" | "eternal";

export interface EvalTurn {
  role: "user" | "assistant";
  content: string;
}

export interface EvalContextBlock {
  kind: ContextKind;
  text: string;
  privacy: Privacy;
}

export interface EvalCase {
  id: string;
  /** The owner's question (the last user turn). */
  prompt: string;
  /** Prior turns, oldest first. Only the `standard` variant sends them all. */
  history?: EvalTurn[];
  /** Memory / device / summary blocks. Only the `standard` variant sends them. */
  context?: EvalContextBlock[];
  /** Overrides the aspect's length budget, in estimated tokens. */
  maxTokens?: number;
}

export interface EvalCaseFile {
  aspect: EvalAspect;
  cases: EvalCase[];
}

/** The bundled prompt files (Resources/Personas), read by the caller. */
export interface PromptSet {
  core: string;
  forge: string;
  eternal: string;
}

/** Mirrors `PersonaConfiguration.maxTokensHint` (Forge 1536, Eternal 512). */
export const ASPECT_MAX_TOKENS: Record<EvalAspect, number> = { forge: 1536, eternal: 512 };

/** Mirrors `Aspect.diagnosticLabel`. */
const ASPECT_LABEL: Record<EvalAspect, string> = { forge: "Forge", eternal: "Eternal" };

/** Mirrors `PromptComposer.cloudOwnerLabel`: cloud prompts never carry the owner's name. */
export const CLOUD_OWNER_LABEL = "the owner";

/**
 * The cloud-bound system prompt, composed like `PromptComposer.compose(destination: .cloud)`:
 * core, then aspect, then the active-aspect line, joined by blank lines, with `{{owner}}`
 * replaced by "the owner". Memory and device notes travel as context blocks instead.
 */
export function composeSystemPrompt(prompts: PromptSet, aspect: EvalAspect): string {
  const resolve = (text: string) => text.replaceAll("{{owner}}", CLOUD_OWNER_LABEL).trim();
  return [resolve(prompts.core), resolve(prompts[aspect]), `Active aspect: ${ASPECT_LABEL[aspect]}.`]
    .filter((part) => part.length > 0)
    .join("\n\n");
}

/**
 * `minimal`: the question plus at most the last user/assistant pair, no context blocks.
 * `standard`: every prior turn and every context block (the router still cuts them down
 * to what each candidate may see).
 */
export type EvalVariant = "minimal" | "standard";
export const VARIANTS: readonly EvalVariant[] = ["minimal", "standard"];

export function buildRequest(
  prompts: PromptSet,
  aspect: EvalAspect,
  evalCase: EvalCase,
  variant: EvalVariant,
): ChatRequestV1 {
  const history = evalCase.history ?? [];
  const turns = variant === "minimal" ? history.slice(-2) : history;
  return {
    taskTier: "answer",
    messages: [
      { role: "system", content: composeSystemPrompt(prompts, aspect) },
      ...turns.map((turn) => ({ role: turn.role, content: turn.content })),
      { role: "user", content: evalCase.prompt },
    ],
    context: variant === "minimal" ? [] : (evalCase.context ?? []).map((block) => ({ ...block })),
    privacy: "cloud",
    maxTokens: budgetFor(aspect, evalCase),
  };
}

export function budgetFor(aspect: EvalAspect, evalCase: EvalCase): number {
  return evalCase.maxTokens ?? ASPECT_MAX_TOKENS[aspect];
}

// MARK: - Rule checks

/** Same estimator as `PromptBudget.estimatedTokens` (characters / 4, rounded down). */
export function estimatedTokens(text: string): number {
  return Math.floor(text.length / 4);
}

const CLICHES: readonly RegExp[] = [
  /\bas an ai\b/i,
  /\bas a (large )?language model\b/i,
  /\bi'?m (just )?(an ai|a (large )?language model)\b/i,
  /\bgreat question\b/i,
  /\bi hope this helps\b/i,
  /\bcertainly!/i,
  /\blet me know if (there'?s|there is) anything else\b/i,
  /\bhappy to help\b/i,
];

const CANON_BREAKS: readonly RegExp[] = [
  /\b(forge|eternal|quicksilver) here\b/i,
  /\[(forge|eternal|quicksilver)\]/i,
  /\b(forge|eternal) (thinks|says|is watching|would say)\b/i,
  /\bhand you (over )?to (forge|eternal)\b/i,
  /\b(i am|i'?m) (an? |your )(ai )?(assistant|chatbot|language model)\b/i,
];

const COSTUME = /\b(thee|thou|thy|thine|mortal|puny)\b/i;
const EMOJI = /\p{Extended_Pictographic}/u;

export type CheckName = "noCliches" | "noEmoji" | "singleEntity" | "noCostume" | "withinBudget";
export const CHECK_NAMES: readonly CheckName[] = [
  "noCliches",
  "noEmoji",
  "singleEntity",
  "noCostume",
  "withinBudget",
];

export function ruleChecks(text: string, budget: number): Record<CheckName, boolean> {
  return {
    noCliches: !CLICHES.some((pattern) => pattern.test(text)),
    noEmoji: !EMOJI.test(text),
    singleEntity: !CANON_BREAKS.some((pattern) => pattern.test(text)),
    noCostume: !COSTUME.test(text),
    withinBudget: estimatedTokens(text) <= budget,
  };
}

// MARK: - Running

export interface EvalRun {
  aspect: EvalAspect;
  caseId: string;
  variant: EvalVariant;
  candidate: string;
  /** The most the router lets this candidate see (`minimal` for any trainsOnPrompts candidate). */
  contextLevel: ContextLevel;
  /** Skipped: no key / binding here, or no daily budget left. Nothing was sent. */
  skipped?: "unavailable" | "budget";
  /** Typed error before output, or the error that closed a started stream. */
  error?: ErrorCode;
  firstTokenMs?: number;
  totalMs?: number;
  output: string;
  outputTokens: number;
  budget: number;
  checks?: Record<CheckName, boolean>;
}

export interface EvalOptions {
  config: RoutingConfig;
  candidates: Candidate[];
  suites: EvalCaseFile[];
  prompts: PromptSet;
  providers: ProviderResolver;
  /** Monotonic milliseconds (default `performance.now`). */
  clock?: () => number;
  /** Wall-clock milliseconds for daily budgets (default `Date.now`). */
  now?: number;
}

interface ParsedEvent {
  event: string;
  data: Record<string, unknown>;
}

/** Splits protocol v1 SSE text into events (the router's own output, so no edge cases). */
function parseEvents(text: string): ParsedEvent[] {
  const events: ParsedEvent[] = [];
  for (const frame of text.split("\n\n")) {
    let event = "";
    let data = "";
    for (const line of frame.split("\n")) {
      if (line.startsWith("event: ")) event = line.slice(7);
      else if (line.startsWith("data: ")) data += line.slice(6);
    }
    if (event !== "") {
      try {
        events.push({ event, data: JSON.parse(data) as Record<string, unknown> });
      } catch {
        events.push({ event, data: {} });
      }
    }
  }
  return events;
}

/** A config holding one candidate, so `routeChat` exercises exactly that candidate. */
function soloConfig(config: RoutingConfig, candidate: Candidate): RoutingConfig {
  return { ...config, tiers: { main: [candidate], backup: [], lastResort: [] } };
}

async function runOne(
  options: EvalOptions,
  budgets: DailyBudgets,
  candidate: Candidate,
  aspect: EvalAspect,
  evalCase: EvalCase,
  variant: EvalVariant,
): Promise<EvalRun> {
  const clock = options.clock ?? (() => performance.now());
  const now = options.now ?? Date.now();
  const budget = budgetFor(aspect, evalCase);
  const base = {
    aspect,
    caseId: evalCase.id,
    variant,
    candidate: candidate.id,
    contextLevel: contextLevel(candidate),
    output: "",
    outputTokens: 0,
    budget,
  };

  if (options.providers(candidate) === null) return { ...base, skipped: "unavailable" };
  if (budgets.remaining(candidate, now) === 0) return { ...base, skipped: "budget" };
  const request = buildRequest(options.prompts, aspect, evalCase, variant);
  const config = soloConfig(options.config, candidate);
  const started = clock();
  const opened = await routeChat(request, { config, budgets, providers: options.providers, now });
  if (!opened.ok) return { ...base, error: opened.error.code, totalMs: clock() - started };

  const reader = opened.body.getReader();
  const decoder = new TextDecoder();
  let raw = "";
  let firstTokenMs: number | undefined;
  for (;;) {
    const next = await reader.read();
    if (next.done) break;
    raw += decoder.decode(next.value, { stream: true });
    if (firstTokenMs === undefined && raw.includes("event: delta")) firstTokenMs = clock() - started;
  }
  raw += decoder.decode();
  const totalMs = clock() - started;

  let output = "";
  let error: ErrorCode | undefined;
  for (const { event, data } of parseEvents(raw)) {
    if (event === "delta" && typeof data.text === "string") output += data.text;
    if (event === "error" && typeof data.code === "string") error = data.code as ErrorCode;
  }
  return {
    ...base,
    error,
    firstTokenMs,
    totalMs,
    output,
    outputTokens: estimatedTokens(output),
    checks: ruleChecks(output, budget),
  };
}

/**
 * Every case x variant x candidate, sequentially (free tiers have low RPM limits). A
 * `trainsOnPrompts` candidate only runs `minimal`: the router redacts its `standard`
 * request to the same thing, so a second call would spend free quota for nothing.
 * Budgets come from `routing.json`, so the harness never asks a candidate for more
 * than the gateway would allow in a day.
 */
export async function runEval(options: EvalOptions): Promise<EvalRun[]> {
  const budgets = new DailyBudgets();
  const runs: EvalRun[] = [];
  for (const suite of options.suites) {
    for (const evalCase of suite.cases) {
      for (const variant of VARIANTS) {
        for (const candidate of options.candidates) {
          if (variant === "standard" && contextLevel(candidate) === "minimal") continue;
          runs.push(await runOne(options, budgets, candidate, suite.aspect, evalCase, variant));
        }
      }
    }
  }
  return runs;
}

// MARK: - Report

export function passed(run: EvalRun): boolean {
  if (run.skipped !== undefined || run.error !== undefined || run.checks === undefined) return false;
  return run.output.trim().length > 0 && CHECK_NAMES.every((name) => run.checks?.[name]);
}

function median(values: number[]): number | undefined {
  if (values.length === 0) return undefined;
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[mid] : ((sorted[mid - 1] ?? 0) + (sorted[mid] ?? 0)) / 2;
}

function ms(value: number | undefined): string {
  return value === undefined ? "–" : `${Math.round(value)} ms`;
}

/** Keeps Markdown table cells on one line and pipe-safe. */
function cell(text: string): string {
  return text.replace(/\s+/g, " ").replace(/\|/g, "\\|").trim();
}

function failedChecks(run: EvalRun): string {
  if (run.skipped !== undefined) return `skipped (${run.skipped})`;
  if (run.checks === undefined) return "–";
  const failed: string[] = CHECK_NAMES.filter((name) => !run.checks?.[name]);
  if (run.output.trim().length === 0) failed.unshift("nonEmpty");
  return failed.length === 0 ? "all pass" : failed.join(", ");
}

const EXCERPT_CHARS = 600;

/** The `results/<date>.md` report. Contains answers to the synthetic cases only: no keys. */
export function renderReport(runs: EvalRun[], meta: { date: string; candidates: Candidate[]; mode: string }): string {
  const lines: string[] = [
    `# Model evaluation: ${meta.date}`,
    "",
    `Mode: ${meta.mode}. Candidates: ${meta.candidates.map((c) => `\`${c.id}\` (${c.model})`).join(", ")}.`,
    "Checks: no assistant clichés, no emoji, single-entity canon, no mock-medieval costume, within the aspect's length budget (docs/mercury-character.md §2.7).",
    "Read the excerpts below for the voice itself; the checks are proxies.",
    "",
    "## Summary",
    "",
    "| Candidate | Runs | Passed | Errors | Skipped | Median first token | Median total | Median output (est. tokens) |",
    "|---|---|---|---|---|---|---|---|",
  ];
  for (const candidate of meta.candidates) {
    const own = runs.filter((run) => run.candidate === candidate.id);
    const ran = own.filter((run) => run.skipped === undefined);
    lines.push(
      `| \`${candidate.id}\` | ${own.length} | ${own.filter(passed).length} | ${ran.filter((r) => r.error !== undefined).length} | ${own.length - ran.length} | ${ms(median(ran.flatMap((r) => (r.firstTokenMs === undefined ? [] : [r.firstTokenMs]))))} | ${ms(median(ran.flatMap((r) => (r.totalMs === undefined ? [] : [r.totalMs]))))} | ${median(ran.filter((r) => r.error === undefined).map((r) => r.outputTokens)) ?? "–"} |`,
    );
  }
  lines.push(
    "",
    "## Runs",
    "",
    "| Aspect | Case | Variant | Candidate | Router allows | First token | Total | Output (est. tokens / budget) | Checks | Error |",
    "|---|---|---|---|---|---|---|---|---|---|",
  );
  for (const run of runs) {
    lines.push(
      `| ${run.aspect} | ${run.caseId} | ${run.variant} | \`${run.candidate}\` | ${run.contextLevel} | ${ms(run.firstTokenMs)} | ${ms(run.totalMs)} | ${run.outputTokens} / ${run.budget} | ${failedChecks(run)} | ${run.error ?? "–"} |`,
    );
  }
  lines.push("", "## Excerpts", "");
  for (const run of runs.filter((r) => r.output.length > 0)) {
    const excerpt = run.output.length > EXCERPT_CHARS ? `${run.output.slice(0, EXCERPT_CHARS)}…` : run.output;
    lines.push(`- **${run.aspect} / ${run.caseId} / ${run.variant} / \`${run.candidate}\`:** ${cell(excerpt)}`);
  }
  lines.push("");
  return lines.join("\n");
}
