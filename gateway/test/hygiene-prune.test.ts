import { describe, expect, it } from "vitest";
import { decideHygiene, persistenceBlocked } from "../src/hygiene-prune";

const live = {
  projects: [
    { name: "Resonance", status: "INACTIVE" as const },
    { name: "Quicksilver: Mercurial intelligence", status: "INACTIVE" as const },
    { name: "WhereamI?", status: "INACTIVE" as const },
  ],
  branches: [
    { repo: "Conduit", name: "release/0.8.0", diverged: true },
    { repo: "Quicksilver", name: "main", archivedRepo: true },
  ],
  pulls: [
    { repo: "Conduit", number: 187, title: "feat: portfolio cutover lattice" },
    { repo: "Conduit", number: 188, title: "⚡ Bolt: optimize keyset cursor validation and task filter construction", author: "cknowlesbadluck" },
    { repo: "Conduit", number: 119, title: "DRAFT KEEP RED: Add managed SSE admission and graceful shutdown" },
    { repo: "Conduit", number: 155, title: "DB TLS: verify Postgres certificates by default (DO NOT MERGE until Render env is set)" },
    { repo: "Resonance", number: 154, title: "feat: portfolio cutover lattice" },
    { repo: "QuicksilverV1", number: 209, title: "chore(deps): bump actions/checkout from 4 to 7 in the actions group", author: "dependabot[bot]" },
  ],
  latticeFamilyOpen: true,
  missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
  legacyArchived: true,
  mcpArchived: true,
};

describe("hygiene prune", () => {
  it("blocks persistence while any Supabase project is inactive", () => {
    expect(persistenceBlocked(live.projects)).toBe(true);
  });

  it("deletes nothing and opens nothing on the live portfolio", () => {
    const decision = decideHygiene(live);
    expect(decision.revision).toBe("2026-10-09-automation-hold");
    expect(decision.openNewWitness).toBe(false);
    expect(decision.deleteBranches).toEqual([]);
    expect(decision.closePulls).toEqual([]);
    expect(decision.mergePulls).toEqual([]);
    expect(decision.persistenceProof).toBe(false);
    expect(decision.singleLegalAction).toBe("owner_unpause_then_set_key");
    expect(decision.dispositions.some((row) => row.target === "Conduit#release/0.8.0" && row.disposition === "hold_not_delete")).toBe(true);
    expect(decision.dispositions.some((row) => row.target === "Conduit#188" && row.disposition === "automation_hold")).toBe(true);
    expect(decision.dispositions.some((row) => row.target === "QuicksilverV1#209" && row.disposition === "automation_hold")).toBe(true);
  });

  it("refuses a new witness family", () => {
    expect(() => decideHygiene({ ...live, latticeFamilyOpen: false })).toThrow(/new witness family/);
  });
});
