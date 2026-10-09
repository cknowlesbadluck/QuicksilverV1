import { describe, expect, it } from "vitest";
import { evaluateSpine, PRUNED_FENCE_BRANCHES } from "../src/phase-spine";

const probe = {
  resonanceReady: 503,
  missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
  readyOmitsOwnerFields: true,
  supabaseInactive: ["Resonance", "Quicksilver", "WhereamI"],
  vercelClass: "alias_absent" as const,
  deviceGateRecorded: false,
  persistenceProven: false,
};

describe("phase spine 13:00 EDT", () => {
  it("stays on phase 0 and records the executed fence prune", () => {
    const decision = evaluateSpine(probe);
    expect(decision.revision).toBe("2026-10-09-phase-spine");
    expect(decision.currentPhase).toBe(0);
    expect(decision.phases[1].state).toBe("satisfied");
    expect(decision.phases[2].state).toBe("satisfied");
    expect(decision.secretInvented).toBe(false);
    expect(decision.pruneExecuted).toEqual([...PRUNED_FENCE_BRANCHES]);
    expect(decision.holdNotDelete).toContain("release/0.8.0");
  });

  it("refuses reopening a pruned fence branch", () => {
    const decision = evaluateSpine(probe, "feat/pause-before-secret");
    expect(decision.reopenRefusal).toBe("refusing to reopen pruned fence branch feat/pause-before-secret");
  });

  it("refuses a ready body that drops the owner key without 200", () => {
    expect(() => evaluateSpine({ ...probe, missingRequired: [], resonanceReady: 503 })).toThrow(/dropped the owner key/);
  });
});
