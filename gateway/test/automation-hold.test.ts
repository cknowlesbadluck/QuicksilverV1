import { describe, expect, it } from "vitest";
import { assertAgentMayMerge, classifyPull, discretionaryCount } from "../src/automation-hold";

const bolt = { repo: "Conduit", number: 188, title: "⚡ Bolt: optimize keyset cursor validation and task filter construction", author: "cknowlesbadluck", mergeableState: "unstable" };
const dependabot = { repo: "QuicksilverV1", number: 209, title: "chore(deps): bump actions/checkout from 4 to 7 in the actions group", author: "dependabot[bot]", mergeableState: "unstable" };
const lattice = { repo: "Conduit", number: 187, title: "feat: portfolio cutover lattice", mergeableState: "unstable" };
const keep = { repo: "Conduit", number: 155, title: "DB TLS: verify Postgres certificates by default", mergeableState: "clean" };

describe("automation hold", () => {
  it("keeps bolt and dependabot out of discretionary scope", () => {
    expect(classifyPull(bolt)).toBe("automation");
    expect(classifyPull(dependabot)).toBe("automation");
    expect(classifyPull(lattice)).toBe("lattice");
    expect(classifyPull(keep)).toBe("keep_red");
    expect(discretionaryCount([bolt, dependabot, lattice, keep])).toBe(1);
  });

  it("refuses unstable automation, keep-red, and lattice merges", () => {
    expect(() => assertAgentMayMerge(bolt)).toThrow(/refusing to merge automation/);
    expect(() => assertAgentMayMerge(keep)).toThrow(/refusing to merge keep-red/);
    expect(() => assertAgentMayMerge(lattice)).toThrow(/owner gate is open/);
  });
});
