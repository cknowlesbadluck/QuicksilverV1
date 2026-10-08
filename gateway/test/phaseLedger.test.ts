import { describe, expect, it } from "vitest";
import { bindingPhase, evaluateDevicePhases } from "../src/phaseLedger";

describe("phase ledger", () => {
  it("does not close the portfolio on simulator CI", () => {
    const phases = evaluateDevicePhases({
      conduitReady: true,
      resonanceOwnerGate: true,
      aliasAbsent: true,
      hardwareRunRecorded: false,
      witnessBudgetSpent: true,
    });
    expect(phases).toHaveLength(10);
    expect(phases[4].state).toBe("owner_blocked");
    expect(bindingPhase(phases)).toBe(1);
    expect(phases[9].state).toBe("open");
  });
});
