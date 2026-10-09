import { describe, expect, it } from "vitest";
import { evaluateBaseDrift, assertStampDoesNotClearOwner, assertHoldNotDeleted, NOT_MERGE } from "../src/base-drift";

const probe = {
  resonanceReady: 503,
  missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
  readyOmitsOwnerFields: true,
  supabaseInactive: ["Resonance", "Quicksilver", "WhereamI"],
  vercelClass: "alias_absent" as const,
  deviceGateRecorded: false,
  secretInvented: false as const,
};

describe("15:00 EDT base drift", () => {
  it("stays on phase 0 and does not merge", () => {
    const decision = evaluateBaseDrift(probe);
    expect(decision.revision).toBe("2026-10-09-base-drift");
    expect(decision.currentPhase).toBe(0);
    expect(decision.stampIsNotAdvance).toBe(true);
    expect(decision.pullMerged).toBe(false);
    expect(decision.driftBefore).toHaveLength(3);
    expect(decision.pruneThisPass).toEqual([]);
    expect(decision.notMerged).toContain(154);
    expect(decision.secretInvented).toBe(false);
  });

  it("refuses a stamp that clears the owner gate", () => {
    expect(() => assertStampDoesNotClearOwner(0, 1)).toThrow(/owner gate/);
    assertStampDoesNotClearOwner(0, 0);
  });

  it("refuses to prune hold and already-pruned fence names", () => {
    expect(() => assertHoldNotDeleted("release/0.8.0")).toThrow(/refusing to prune/);
    expect(() => assertHoldNotDeleted("feat/pause-before-secret")).toThrow(/refusing to prune/);
    expect(NOT_MERGE).toContain(209);
  });
});
