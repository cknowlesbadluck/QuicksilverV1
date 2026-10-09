import { describe, expect, it } from "vitest";
import { classifyHost, decideCutover, discretionaryOpen } from "../src/cutover-lattice";

describe("cutover lattice", () => {
  it("admits only the owner gate and ignores archived entropy", () => {
    const decision = decideCutover({
      hosts: [
        { name: "conduit", httpStatus: 200, missingRequired: [] },
        {
          name: "resonance",
          httpStatus: 503,
          missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
          bodyHasContractRevision: false,
          bodyHasOwnerActionRequired: false,
        },
        { name: "vercel", httpStatus: 404, deploymentNotFound: true },
      ],
      repos: [
        { repo: "Conduit", openPullRequests: 5, keepRed: 4 },
        { repo: "Quicksilver", openPullRequests: 2, keepRed: 0, archived: true },
      ],
      legacyQuicksilverArchived: true,
      latticeFamilyOpen: true,
    });
    expect(classifyHost({ name: "vercel", httpStatus: 404, deploymentNotFound: true })).toBe("alias_absent");
    expect(discretionaryOpen({ repo: "Conduit", openPullRequests: 5, keepRed: 4 })).toBe(1);
    expect(decision.admittedPhase).toBe("p0_owner_gates");
    expect(decision.admission).toBe("owner_only");
    expect(decision.refreshInPlace).toBe(true);
    expect(decision.ownerActions.join(" ")).toContain("Do not invent");
    expect(decision.ownerActions.join(" ")).toContain("is archived");
  });

  it("does not treat keep-red pulls as an entropy breach after the owner gate closes", () => {
    const decision = decideCutover({
      hosts: [
        { name: "conduit", httpStatus: 200, missingRequired: [] },
        { name: "resonance", httpStatus: 200, missingRequired: [] },
      ],
      repos: [{ repo: "Conduit", openPullRequests: 5, keepRed: 4 }],
      legacyQuicksilverArchived: true,
    });
    expect(decision.entropyBreach).toBe(false);
    expect(decision.admittedPhase).toBe("p2_ready_parity");
  });
});
