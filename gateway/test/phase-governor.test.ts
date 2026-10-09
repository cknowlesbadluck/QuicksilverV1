import { describe, expect, it } from "vitest";
import { classifyBranch, decide, type Probe } from "../src/phase-governor";

const probe: Probe = {
  conduitHealth: 200,
  conduitReady: 200,
  conduitVersion: "0.8.0",
  contractRevision: "2026-10-03-ready-surface",
  persistence: "postgres",
  diagnosticsOk: true,
  resonanceReady: 503,
  missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
  readyBodyOmitsOwnerAction: true,
  vercelStatus: 404,
  vercelClass: "alias_absent",
  supabasePaused: true,
  deviceGateRecorded: false,
  persistenceProven: false,
  discretionaryOpen: { conduit: 1, resonance: 1, quicksilver: 1 },
  activityPruned: 0,
};

describe("phase governor", () => {
  it("holds the 06:00 EDT probe on phase 0 and invents no delete", () => {
    const decision = decide(probe, [
      { repo: "QuicksilverV1", name: "main", openPull: null, divergedRelease: false },
      { repo: "QuicksilverV1", name: "feat/cutover-lattice-1000", openPull: 242, divergedRelease: false },
      { repo: "QuicksilverV1", name: "dependabot/github_actions/actions-640176b5ab", openPull: 209, divergedRelease: false },
    ]);
    expect(decision.currentPhase).toBe(0);
    expect(decision.deleteCandidates).toEqual([]);
    expect(classifyBranch({ repo: "Conduit", name: "release/0.8.0", openPull: null, divergedRelease: true })).toBe("hold_diverged");
  });

  it("opens persistence after the owner gate and still blocks the device gate", () => {
    const open = decide({ ...probe, supabasePaused: false, missingRequired: [], resonanceReady: 200 }, []);
    expect(open.currentPhase).toBe(3);
    expect(open.phases[8].state).toBe("blocked");
    expect(open.phases[8].blocker).toBe("device HG unrecorded");
  });
});
