/**
 * Per-token RPM limit and per-candidate daily request budgets (M3-T16).
 *
 * Best-effort, in-isolate counters. Each Worker isolate keeps its own counts and loses
 * them on eviction, so these limits are a soft guard that keeps the gateway well under
 * each provider's free cap. They are not exact global quotas. No KV or other storage
 * writes happen per request, and no paid bindings are used. (The Workers Rate Limiting
 * binding is not used: its docs don't state that it is part of Workers Free.)
 *
 * Budgets reset at 00:00 UTC. A provider that resets on another clock (Gemini: midnight
 * Pacific) gets a budget under half its free daily limit, because one provider day can
 * overlap two UTC days. `test/limits.test.ts` enforces that rule on `routing.json`.
 */

import routingJson from "../config/routing.json";

export type Tier = "main" | "backup" | "lastResort";

export interface Candidate {
  id: string;
  provider: string;
  model: string;
  /** Client-safe model label for `GET /v1/config` (M3-T20). */
  displayModel: string;
  /** True when the provider may train on prompts: the router then sends minimal context. */
  trainsOnPrompts: boolean;
  /** Ceiling on the output tokens the router asks this candidate for (M3-T20). */
  maxOutputTokens: number;
  /** Requests per UTC day the gateway allows for this candidate. */
  dailyBudget: number;
  /** The provider's free daily request limit (reference for the budget rule). */
  freeDailyRequests: number;
  /** False when the provider's daily limit resets on a clock other than 00:00 UTC. */
  freeResetsAtUtcMidnight: boolean;
}

/** Router timeouts per upstream attempt (M3-T20). */
export interface RouterTimeouts {
  /** No first chunk within this window: abort the attempt and fail over (`timeout`). */
  firstByteMs: number;
  /** No next chunk within this window after output began: close with `timeout`. */
  idleMs: number;
}

export interface RoutingConfig {
  rpmPerToken: number;
  timeouts: RouterTimeouts;
  tiers: Record<Tier, Candidate[]>;
}

export const TIER_ORDER: readonly Tier[] = ["main", "backup", "lastResort"];

export const routingConfig: RoutingConfig = routingJson as RoutingConfig;

/** Candidates in failover order: main, then backup, then last resort. */
export function orderedCandidates(config: RoutingConfig): Candidate[] {
  return TIER_ORDER.flatMap((tier) => config.tiers[tier] ?? []);
}

const MINUTE_MS = 60_000;

export type RateDecision = { ok: true } | { ok: false; retryAfter: number };

/** Sliding one-minute window per token key. Memory per key is bounded by the limit. */
export class RpmLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(private readonly limit: number) {}

  check(key: string, now: number): RateDecision {
    const windowStart = now - MINUTE_MS;
    const recent = (this.hits.get(key) ?? []).filter((t) => t > windowStart);
    if (recent.length >= this.limit) {
      this.hits.set(key, recent);
      const oldest = recent[0];
      const retryAfter = Math.max(1, Math.ceil((oldest + MINUTE_MS - now) / 1000));
      return { ok: false, retryAfter };
    }
    recent.push(now);
    this.hits.set(key, recent);
    return { ok: true };
  }
}

/** `YYYY-MM-DD` for the UTC day containing `now`. */
export function utcDay(now: number): string {
  return new Date(now).toISOString().slice(0, 10);
}

/** Per-candidate request counts for the current UTC day. */
export class DailyBudgets {
  private readonly used = new Map<string, { day: string; count: number }>();

  private countFor(candidate: Candidate, now: number): number {
    const entry = this.used.get(candidate.id);
    return entry && entry.day === utcDay(now) ? entry.count : 0;
  }

  remaining(candidate: Candidate, now: number): number {
    return Math.max(0, candidate.dailyBudget - this.countFor(candidate, now));
  }

  /** Records one request. Returns false (and records nothing) when the budget is spent. */
  tryConsume(candidate: Candidate, now: number): boolean {
    const count = this.countFor(candidate, now);
    if (count >= candidate.dailyBudget) return false;
    this.used.set(candidate.id, { day: utcDay(now), count: count + 1 });
    return true;
  }
}

/** First candidate in failover order with budget left today, or null when all are spent. */
export function firstCandidateWithBudget(
  config: RoutingConfig,
  budgets: DailyBudgets,
  now: number,
): Candidate | null {
  return orderedCandidates(config).find((c) => budgets.remaining(c, now) > 0) ?? null;
}
