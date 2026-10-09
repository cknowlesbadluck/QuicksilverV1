import { describe, expect, it } from "vitest";
import { DEVICE_FENCE_LANDED, classifyLanded, holdContradictions } from "./landed-fence";

describe("landed fence", () => {
  it("treats a merged device fence without a device record as unverified", () => {
    expect(classifyLanded(DEVICE_FENCE_LANDED)).toBe("landed_unverified");
    expect(DEVICE_FENCE_LANDED.sha).toBe("83f13504cda74e4150baab3be3de70f2251ab441");
    expect(holdContradictions([241, 242], [DEVICE_FENCE_LANDED])).toEqual([241]);
  });

  it("accepts a recorded device gate", () => {
    expect(classifyLanded({ ...DEVICE_FENCE_LANDED, deviceRecorded: true })).toBe("landed_accepted");
  });
});
