import { describe, expect, it } from "vitest";
import {
  DailyBudgets,
  RpmLimiter,
  firstCandidateWithBudget,
  orderedCandidates,
  routingConfig,
  utcDay,
  type Candidate,
} from "../src/limits";

const T0 = Date.parse("2026-10-05T12:00:00.000Z");

describe("RpmLimiter", () => {
  it("allows the limit within a minute, then rate-limits with retryAfter", () => {
    const limiter = new RpmLimiter(3);
    for (let i = 0; i < 3; i += 1) {
      expect(limiter.check("k", T0 + i * 1000)).toEqual({ ok: true });
    }
    expect(limiter.check("k", T0 + 10_000)).toEqual({ ok: false, retryAfter: 50 });
  });

  it("slides: a slot frees up 60 s after the oldest admitted request", () => {
    const limiter = new RpmLimiter(2);
    limiter.check("k", T0);
    limiter.check("k", T0 + 30_000);
    expect(limiter.check("k", T0 + 59_999).ok).toBe(false);
    expect(limiter.check("k", T0 + 60_000)).toEqual({ ok: true });
  });

  it("keeps separate windows per token key", () => {
    const limiter = new RpmLimiter(1);
    expect(limiter.check("a", T0).ok).toBe(true);
    expect(limiter.check("b", T0).ok).toBe(true);
    expect(limiter.check("a", T0).ok).toBe(false);
  });
});

describe("DailyBudgets", () => {
  const candidate: Candidate = {
    id: "test",
    provider: "fake",
    model: "fake",
    trainsOnPrompts: false,
    dailyBudget: 2,
    freeDailyRequests: 5,
    freeResetsAtUtcMidnight: true,
  };

  it("stops at the daily budget", () => {
    const budgets = new DailyBudgets();
    expect(budgets.tryConsume(candidate, T0)).toBe(true);
    expect(budgets.tryConsume(candidate, T0)).toBe(true);
    expect(budgets.remaining(candidate, T0)).toBe(0);
    expect(budgets.tryConsume(candidate, T0)).toBe(false);
  });

  it("resets on a new UTC day", () => {
    const budgets = new DailyBudgets();
    const lastMs = Date.parse("2026-10-05T23:59:59.999Z");
    const nextDay = Date.parse("2026-10-06T00:00:00.000Z");
    budgets.tryConsume(candidate, lastMs);
    budgets.tryConsume(candidate, lastMs);
    expect(budgets.tryConsume(candidate, lastMs)).toBe(false);
    expect(utcDay(nextDay)).toBe("2026-10-06");
    expect(budgets.remaining(candidate, nextDay)).toBe(2);
    expect(budgets.tryConsume(candidate, nextDay)).toBe(true);
  });

  it("falls through candidates in order and returns null when all are spent", () => {
    const budgets = new DailyBudgets();
    const [main, backup, lastResort] = orderedCandidates(routingConfig);
    expect(firstCandidateWithBudget(routingConfig, budgets, T0)).toBe(main);
    while (budgets.tryConsume(main, T0));
    expect(firstCandidateWithBudget(routingConfig, budgets, T0)).toBe(backup);
    while (budgets.tryConsume(backup, T0));
    expect(firstCandidateWithBudget(routingConfig, budgets, T0)).toBe(lastResort);
    while (budgets.tryConsume(lastResort, T0));
    expect(firstCandidateWithBudget(routingConfig, budgets, T0)).toBeNull();
  });
});

describe("config/routing.json", () => {
  it("keeps the owner's order: Gemini Flash -> Groq gpt-oss-120b -> Workers AI", () => {
    const candidates = orderedCandidates(routingConfig);
    expect(candidates.map((c) => [c.provider, c.model])).toEqual([
      ["gemini", "gemini-3.7-flash"],
      ["groq", "openai/gpt-oss-120b"],
      ["workersAI", "@cf/meta/llama-3.1-8b-instruct-fp8-fast"],
    ]);
    expect(candidates.map((c) => c.trainsOnPrompts)).toEqual([true, false, false]);
    expect(candidates.some((c) => c.provider === "xai")).toBe(false);
    expect(new Set(candidates.map((c) => c.id)).size).toBe(candidates.length);
  });

  it("keeps every daily budget below the provider's free daily limit", () => {
    for (const c of orderedCandidates(routingConfig)) {
      expect(Number.isInteger(c.dailyBudget) && c.dailyBudget > 0).toBe(true);
      // A provider day on another clock can span two UTC days, so stay under half.
      const ceiling = c.freeResetsAtUtcMidnight ? c.freeDailyRequests : c.freeDailyRequests / 2;
      expect(c.dailyBudget).toBeLessThan(ceiling);
    }
    expect(Number.isInteger(routingConfig.rpmPerToken) && routingConfig.rpmPerToken > 0).toBe(
      true,
    );
  });

  it("holds no secrets", () => {
    expect(JSON.stringify(routingConfig)).not.toMatch(/api_?key|secret|device_?token|bearer/i);
  });
});
