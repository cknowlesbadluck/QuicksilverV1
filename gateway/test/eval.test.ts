import { describe, expect, it } from "vitest";
import coreTxt from "../../Resources/Personas/core.txt?raw";
import eternalTxt from "../../Resources/Personas/eternal.txt?raw";
import forgeTxt from "../../Resources/Personas/forge.txt?raw";
import { fakeCandidate, fakeProviders, FAKE_CANDIDATES } from "../eval/fake";
import {
  buildRequest,
  composeSystemPrompt,
  passed,
  renderReport,
  ruleChecks,
  runEval,
  type EvalCase,
  type PromptSet,
} from "../eval/harness";
import { parseArgs, resolveCandidates, runFromArgs, SUITES, PROMPT_PATHS, type EvalIO } from "../eval/run";
import { routingConfig, orderedCandidates } from "../src/limits";
import type { Provider, ProviderStreamCall } from "../src/stream";

const PROMPTS: PromptSet = { core: coreTxt, forge: forgeTxt, eternal: eternalTxt };

const FILES: Record<string, string> = {
  [PROMPT_PATHS.core]: coreTxt,
  [PROMPT_PATHS.forge]: forgeTxt,
  [PROMPT_PATHS.eternal]: eternalTxt,
};

function memoryIO(env: EvalIO["env"] = {}) {
  const written = new Map<string, string>();
  const logs: string[] = [];
  const io: EvalIO = {
    readText: (path) => {
      const text = FILES[path];
      if (text === undefined) throw new Error(`no such file: ${path}`);
      return text;
    },
    writeText: (path, text) => written.set(path, text),
    env,
    today: "2026-10-05",
    log: (line) => logs.push(line),
  };
  return { io, written, logs };
}

describe("eval cases", () => {
  it("has Forge and Eternal suites with unique ids", () => {
    expect(SUITES.map((suite) => suite.aspect)).toEqual(["forge", "eternal"]);
    for (const suite of SUITES) {
      expect(suite.cases.length).toBeGreaterThanOrEqual(3);
      const ids = suite.cases.map((evalCase) => evalCase.id);
      expect(new Set(ids).size).toBe(ids.length);
    }
  });

  it("never carries the owner's name or anything that looks like a key", () => {
    const text = JSON.stringify(SUITES);
    expect(text).not.toMatch(/christopher/i);
    expect(text).not.toMatch(/AIza|gsk_|xai-|sk-/);
  });
});

describe("request building", () => {
  const evalCase: EvalCase = {
    id: "t",
    prompt: "Now?",
    history: [
      { role: "user", content: "a" },
      { role: "assistant", content: "b" },
      { role: "user", content: "c" },
      { role: "assistant", content: "d" },
    ],
    context: [{ kind: "memory", text: "note", privacy: "cloud" }],
  };

  it("composes core, aspect and the active-aspect line for the cloud, without the owner's name", () => {
    const system = composeSystemPrompt(PROMPTS, "eternal");
    expect(system.startsWith(coreTxt.trim().replaceAll("{{owner}}", "the owner"))).toBe(true);
    expect(system).toContain("Eternal aspect");
    expect(system.endsWith("Active aspect: Eternal.")).toBe(true);
    expect(system).not.toContain("{{owner}}");
    expect(system).not.toMatch(/christopher/i);
  });

  it("minimal keeps the last pair and no context; standard keeps everything", () => {
    const minimal = buildRequest(PROMPTS, "forge", evalCase, "minimal");
    expect(minimal.messages.map((m) => m.content).slice(1)).toEqual(["c", "d", "Now?"]);
    expect(minimal.context).toEqual([]);
    expect(minimal.maxTokens).toBe(1536);

    const standard = buildRequest(PROMPTS, "eternal", evalCase, "standard");
    expect(standard.messages.map((m) => m.content).slice(1)).toEqual(["a", "b", "c", "d", "Now?"]);
    expect(standard.context).toHaveLength(1);
    expect(standard.maxTokens).toBe(512);
    expect(standard.privacy).toBe("cloud");
  });
});

describe("rule checks", () => {
  it("passes a clean in-voice answer", () => {
    expect(Object.values(ruleChecks("So it was. Keep the decision.", 512)).every(Boolean)).toBe(true);
  });

  it.each([
    ["Great question! The cache.", "noCliches"],
    ["As an AI, I cannot know.", "noCliches"],
    ["I hope this helps.", "noCliches"],
    ["Done 🚀", "noEmoji"],
    ["Forge here! Let's build.", "singleEntity"],
    ["[Eternal] So it was.", "singleEntity"],
    ["I'm your AI assistant.", "singleEntity"],
    ["Hear me, mortal.", "noCostume"],
  ] as const)("flags %j as %s", (text, check) => {
    expect(ruleChecks(text, 512)[check]).toBe(false);
  });

  it("enforces the length budget in estimated tokens (chars / 4)", () => {
    expect(ruleChecks("x".repeat(40), 10).withinBudget).toBe(true);
    expect(ruleChecks("x".repeat(44), 10).withinBudget).toBe(false);
  });
});

describe("runEval against the fake (CI smoke)", () => {
  it("runs every case through the router and passes every check", async () => {
    const runs = await runEval({
      config: routingConfig,
      candidates: [...FAKE_CANDIDATES],
      suites: SUITES,
      prompts: PROMPTS,
      providers: fakeProviders,
    });
    const cases = SUITES.reduce((sum, suite) => sum + suite.cases.length, 0);
    // The training fake runs minimal only; the other runs minimal and standard.
    expect(runs).toHaveLength(cases * 3);
    for (const run of runs) {
      expect(passed(run)).toBe(true);
      expect(run.firstTokenMs).toBeGreaterThanOrEqual(0);
      expect(run.totalMs).toBeGreaterThanOrEqual(run.firstTokenMs ?? 0);
      expect(run.outputTokens).toBeGreaterThan(0);
    }
    expect(runs.filter((r) => r.candidate === "fake-main").every((r) => r.contextLevel === "minimal")).toBe(true);
    expect(runs.some((r) => r.candidate === "fake-backup" && r.variant === "standard")).toBe(true);
    expect(runs.find((r) => r.aspect === "eternal")?.output).toContain("So it was.");
  });

  it("sends a training candidate no context blocks, even in the standard suite", async () => {
    const seen: { candidate: string; request: ProviderStreamCall["request"] }[] = [];
    const spyFor = (candidate: string): Provider => ({
      id: "spy",
      async *stream({ request }) {
        seen.push({ candidate, request });
        yield { type: "delta", text: "So it was." };
        yield { type: "done" };
      },
    });
    await runEval({
      config: routingConfig,
      candidates: [fakeCandidate("fake-main", true), fakeCandidate("fake-backup", false)],
      suites: SUITES,
      prompts: PROMPTS,
      providers: (candidate) => spyFor(candidate.id),
    });
    const main = seen.filter((call) => call.candidate === "fake-main");
    expect(main.length).toBeGreaterThan(0);
    expect(main.every((call) => call.request.context.length === 0)).toBe(true);
    expect(seen.some((call) => call.candidate === "fake-backup" && call.request.context.length > 0)).toBe(true);
  });

  it("records a typed error and skips unavailable candidates without calling them", async () => {
    const runs = await runEval({
      config: routingConfig,
      candidates: [fakeCandidate("fake-down", false), { ...fakeCandidate("no-key", false), provider: "gemini" }],
      suites: [SUITES[0]!],
      prompts: PROMPTS,
      providers: fakeProviders,
    });
    const down = runs.filter((r) => r.candidate === "fake-down");
    expect(down.every((r) => r.error === "upstream_unavailable" && !passed(r))).toBe(true);
    const skipped = runs.filter((r) => r.candidate === "no-key");
    expect(skipped.every((r) => r.skipped === "unavailable" && r.totalMs === undefined)).toBe(true);

    const report = renderReport(runs, { date: "2026-10-05", candidates: [], mode: "fake" });
    expect(report).toContain("upstream_unavailable");
    expect(report).toContain("skipped (unavailable)");
  });

  it("skips a candidate once its daily budget is spent", async () => {
    const runs = await runEval({
      config: routingConfig,
      candidates: [{ ...fakeCandidate("tight", false), dailyBudget: 2 }],
      suites: [SUITES[0]!],
      prompts: PROMPTS,
      providers: fakeProviders,
    });
    expect(runs.filter((r) => r.skipped === undefined)).toHaveLength(2);
    expect(runs.filter((r) => r.skipped === "budget").length).toBe(runs.length - 2);
  });
});

describe("npm run eval", () => {
  it("--fake writes results/<date>-fake.md and succeeds", async () => {
    const { io, written, logs } = memoryIO();
    const outcome = await runFromArgs(["--fake"], io);
    expect(outcome.ok).toBe(true);
    expect(outcome.reportPath).toBe("eval/results/2026-10-05-fake.md");
    const report = written.get(outcome.reportPath) ?? "";
    expect(report).toContain("# Model evaluation: 2026-10-05");
    expect(report).toContain("| `fake-main` |");
    expect(report).toContain("all pass");
    expect(logs[0]).toMatch(/^eval: \d+\/\d+ runs passed/);
  });

  it("with no keys skips every live candidate and sends nothing", async () => {
    const { io, written } = memoryIO({});
    const outcome = await runFromArgs([], io);
    expect(outcome.reportPath).toBe("eval/results/2026-10-05.md");
    expect(outcome.runs.length).toBeGreaterThan(0);
    expect(outcome.runs.every((run) => run.skipped === "unavailable")).toBe(true);
    expect(written.get(outcome.reportPath)).toContain("`gemini-flash`");
  });

  it("parses --candidates, --out and ad-hoc provider:model candidates", () => {
    expect(parseArgs(["--candidates", "gemini-flash, groq:llama-x", "--out", "tmp"])).toEqual({
      fake: false,
      candidates: ["gemini-flash", "groq:llama-x"],
      outDir: "tmp",
    });
    expect(() => parseArgs(["--bogus"])).toThrow(/unknown argument/);
    expect(() => parseArgs(["--candidates"])).toThrow(/needs a value/);
    expect(() => parseArgs(["--candidates", " , "])).toThrow(/at least one candidate/);
    expect(() => parseArgs(["--out", ""])).toThrow(/non-empty directory/);
    expect(() => parseArgs(["--out", "  "])).toThrow(/non-empty directory/);
    expect(() => parseArgs(["--out", "/"])).toThrow(/non-empty directory/);
    expect(parseArgs(["--out", "tmp/"]).outDir).toBe("tmp");

    const pool = orderedCandidates(routingConfig);
    const [known, groq, gemini] = resolveCandidates(["gemini-flash", "groq:llama-x", "gemini:pro-x"], pool);
    expect(known?.trainsOnPrompts).toBe(true);
    expect(groq).toMatchObject({ provider: "groq", model: "llama-x", trainsOnPrompts: false });
    expect(gemini).toMatchObject({ provider: "gemini", trainsOnPrompts: true });
    expect(() => resolveCandidates(["nope"], pool)).toThrow(/unknown candidate/);
  });
});
