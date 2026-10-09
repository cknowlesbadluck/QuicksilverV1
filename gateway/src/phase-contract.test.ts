import { describe, expect, it } from "vitest";
import { PHASES, classifyProbe, assertNoSecretInvention, assertStampDoesNotAdvance } from "./phase-contract";

const live = {
  resonanceStatus: 503,
  resonanceMissing: ["SUPABASE_SERVICE_ROLE_KEY"],
  vercelStatus: 404,
  supabasePaused: true,
  deviceHgRecorded: false
};

describe("phase contract", () => {
  it("keeps the owner gate at phase 2 and refuses a stamp", () => {
    expect(PHASES).toHaveLength(10);
    const before = classifyProbe(live);
    expect(before.currentPhase).toBe(2);
    expect(before.ownerBlocked).toBe(true);
    expect(before.secretsInvented).toBe(false);
    expect(() => assertStampDoesNotAdvance(before, { ...before, ownerBlocked: false })).toThrow(/owner gate/);
    expect(() => assertNoSecretInvention({ key: "eyJhbGciOi" })).toThrow(/secret/);
  });

  it("does not treat gateway health as device acceptance", () => {
    expect(classifyProbe(live).deviceUnrecorded).toBe(true);
    expect(classifyProbe({ ...live, deviceHgRecorded: true }).currentPhase).toBe(2);
  });

  it("does not treat a Vercel 404 as the public gate", () => {
    expect(classifyProbe(live).aliasAbsent).toBe(true);
  });
});
