/**
 * Fake candidates for the eval harness (M3-T21). CI runs the harness only against these:
 * no network, no keys. Each fake reads which aspect the system prompt asked for and
 * streams a short canned answer in that aspect's voice, so the smoke test proves the
 * whole path (request building, router, redaction, stream parsing, checks, report).
 */

import type { Candidate } from "../src/limits";
import type { ProviderResolver } from "../src/router";
import type { Provider, ProviderChunk, ProviderStreamCall } from "../src/stream";

const FORGE_REPLY = [
  "Three leaps. One: the cache. No, wait, better: ",
  "the actor hop is the cost, not the cache. ",
  "Snap: move the read off the main actor and batch it. ",
  "Next step: wrap the fetch in one Task and time it with signposts.",
];

const ETERNAL_REPLY = [
  "So it was. ",
  "You chose the slower path once before, and it held. ",
  "Keep the decision. What will it cost you in a year?",
];

/** `fake-voice` answers in voice; `fake-down` always fails before output (failover path). */
export type FakeBehaviour = "voice" | "down";

class EvalFakeProvider implements Provider {
  readonly id = "fake";

  constructor(private readonly behaviour: FakeBehaviour) {}

  async *stream({ request, signal }: ProviderStreamCall): AsyncGenerator<ProviderChunk> {
    if (this.behaviour === "down") {
      yield { type: "error", code: "upstream_unavailable" };
      return;
    }
    const system = request.messages.find((message) => message.role === "system")?.content ?? "";
    const reply = system.includes("Active aspect: Eternal.") ? ETERNAL_REPLY : FORGE_REPLY;
    for (const text of reply) {
      if (signal.aborted) return;
      yield { type: "delta", text };
    }
    yield { type: "done", usage: { promptTokens: Math.floor(system.length / 4), completionTokens: 40 } };
  }
}

function fakeCandidate(id: string, trainsOnPrompts: boolean): Candidate {
  return {
    id,
    provider: "fake",
    model: id,
    displayModel: id,
    trainsOnPrompts,
    maxOutputTokens: 1536,
    dailyBudget: 1000,
    freeDailyRequests: 1000,
    freeResetsAtUtcMidnight: true,
  };
}

/** One training-style fake (gets `minimal`) and one non-training fake (gets `standard`). */
export const FAKE_CANDIDATES: readonly Candidate[] = [
  fakeCandidate("fake-main", true),
  fakeCandidate("fake-backup", false),
];

/** Resolves every `provider: "fake"` candidate; ids containing "down" always fail. */
export const fakeProviders: ProviderResolver = (candidate) =>
  candidate.provider === "fake"
    ? new EvalFakeProvider(candidate.id.includes("down") ? "down" : "voice")
    : null;

export { fakeCandidate };
