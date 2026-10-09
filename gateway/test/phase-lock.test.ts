import { describe, expect, it } from "vitest";
import { decidePhaseLock, disposePull, KEEP_RED, type OpenPull } from "../src/phase-lock";

const pulls: OpenPull[] = [
  { repo: "QuicksilverV1", number: 242, title: "feat: portfolio cutover lattice" },
  { repo: "QuicksilverV1", number: 241, title: "feat: refuse device acceptance on gateway health" },
  { repo: "QuicksilverV1", number: 240, title: "feat: entropy governor for witness budget and keep-red" },
  { repo: "QuicksilverV1", number: 238, title: "feat: degrade planner for host probes and gateway errors" },
  { repo: "QuicksilverV1", number: 209, title: "chore(deps): bump actions/checkout from 4 to 7 in the actions group" },
];

describe("phase lock", () => {
  it("closes superseded families and holds the device fence", () => {
    const decision = decidePhaseLock({ latticeOpen: true, pulls });
    expect(decision.openNewWitness).toBe(false);
    expect(decision.closeNumbers.sort((a, b) => a - b)).toEqual([238, 240]);
    expect(decision.holdNumbers).toContain(241);
    expect(decision.holdNumbers).toContain(209);
    for (const number of KEEP_RED) {
      expect(disposePull({ repo: "Conduit", number, title: "keep" }, true)).toBe("keep_red");
    }
  });

  it("holds older families when the lattice pull is absent", () => {
    expect(disposePull({ repo: "QuicksilverV1", number: 240, title: "feat: entropy governor" }, false)).toBe("hold");
  });
});
