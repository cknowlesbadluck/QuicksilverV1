/**
 * Deterministic fake upstream (M3-T17). Scripted chunks, errors, throws and delays, with
 * no network. Used by Vitest and by local `FAKE_MODE` (`wrangler dev` with a `.dev.vars`
 * file; never set FAKE_MODE on the deployed Worker).
 *
 * Every script in `FAKE_SCRIPTS` reproduces one file in gateway/fixtures byte for byte
 * when run through `openV1Stream` (see test/stream.test.ts).
 */

import type { ErrorCode, Meta, Provider, ProviderChunk, ProviderStreamCall } from "../stream";

export type FakeStep =
  | ProviderChunk
  | { type: "delay"; ms: number }
  /** Throws from the provider, like a dropped upstream connection. */
  | { type: "throw" };

export interface FakeScript {
  meta: Meta;
  steps: FakeStep[];
}

const FAKE_META: Meta = { route: "cloud", model: "fake", trainsOnPrompts: true };

function errorScript(code: ErrorCode, retryAfter?: number): FakeScript {
  const step: FakeStep =
    retryAfter === undefined ? { type: "error", code } : { type: "error", code, retryAfter };
  return { meta: FAKE_META, steps: [step] };
}

/** Named scripts, one per gateway/fixtures/*.sse stream fixture. */
export const FAKE_SCRIPTS = {
  happy: {
    meta: { route: "on-device", model: "fake", trainsOnPrompts: false },
    steps: [
      { type: "delta", text: "Forge" },
      { type: "done", usage: { promptTokens: 12, completionTokens: 1 } },
    ],
  },
  "mid-stream-error": {
    meta: FAKE_META,
    steps: [
      { type: "delta", text: "partial" },
      { type: "error", code: "upstream_unavailable" },
    ],
  },
  "rate-limited": errorScript("rate_limited", 2),
  timeout: errorScript("timeout"),
  "upstream-unavailable": errorScript("upstream_unavailable"),
  "budget-exhausted": errorScript("budget_exhausted"),
  "bad-request": errorScript("bad_request"),
  unauthorized: errorScript("unauthorized"),
} satisfies Record<string, FakeScript>;

export type FakeScenario = keyof typeof FAKE_SCRIPTS;

/**
 * Maps a `FAKE_MODE` value to a scenario. `"1"` / `"true"` mean `happy`. Anything else
 * (unset, empty, unknown) is null, so fake mode stays off unless named exactly.
 */
export function fakeScenario(mode: string | undefined): FakeScenario | null {
  if (mode === undefined) return null;
  const value = mode.trim();
  if (value === "1" || value === "true") return "happy";
  return Object.hasOwn(FAKE_SCRIPTS, value) ? (value as FakeScenario) : null;
}

function abortError(): DOMException {
  return new DOMException("The fake upstream was aborted.", "AbortError");
}

function sleep(ms: number, signal: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    if (signal.aborted) {
      reject(abortError());
      return;
    }
    const onAbort = () => {
      clearTimeout(timer);
      reject(abortError());
    };
    const timer = setTimeout(() => {
      signal.removeEventListener("abort", onAbort);
      resolve();
    }, ms);
    signal.addEventListener("abort", onAbort, { once: true });
  });
}

export class FakeProvider implements Provider {
  readonly id = "fake";

  constructor(readonly script: FakeScript) {}

  get meta(): Meta {
    return this.script.meta;
  }

  async *stream({ signal }: ProviderStreamCall): AsyncGenerator<ProviderChunk> {
    for (const step of this.script.steps) {
      if (signal.aborted) throw abortError();
      if (step.type === "delay") {
        await sleep(step.ms, signal);
      } else if (step.type === "throw") {
        throw new Error("fake upstream dropped the connection");
      } else {
        yield step;
      }
    }
  }
}
