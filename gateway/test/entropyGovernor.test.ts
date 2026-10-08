import { describe, expect, it } from "vitest";
import { admitWork, classifyDeviceClaim, classifyProbe } from "../src/entropyGovernor";

describe("device fence", () => {
  it("does not treat simulator CI as iPhone 16e acceptance", () => {
    expect(classifyDeviceClaim({ simulatorCiGreen: true, hardwareRunRecorded: false })).toEqual({
      accepted: false,
      reason: "simulator_is_not_device_hg",
    });
    expect(classifyDeviceClaim({ simulatorCiGreen: true, hardwareRunRecorded: true }).accepted).toBe(true);
  });

  it("classifies the live portfolio probes and blocks witness stacking", () => {
    expect(classifyProbe("resonance_ready", 503, { missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"] })).toBe(
      "resonance_owner_gate",
    );
    expect(classifyProbe("vercel_alias", 404, {})).toBe("alias_absent");
    expect(admitWork("witness", 2)).toBe(false);
    expect(admitWork("implementation", 2)).toBe(true);
  });
});
