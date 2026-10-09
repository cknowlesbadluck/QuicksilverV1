import { describe, expect, it } from "vitest";
import { evaluateAudit, assertStampDoesNotClearOwner, HOLD_NOT_DELETE } from "../src/audit-hardening";

const probe = {
  resonanceReady: 503,
  missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
  readyOmitsOwnerFields: true,
  supabaseInactive: ["Resonance", "Quicksilver", "WhereamI"],
  vercelClass: "alias_absent" as const,
  deviceGateRecorded: false,
  persistenceProven: false,
};

const liveRefs = [
  { repo: "Conduit", name: "main", openPull: null },
  { repo: "Conduit", name: "release/0.8.0", openPull: null },
  { repo: "Conduit", name: "feat/cutover-lattice-1000", openPull: 187 },
  { repo: "Conduit", name: "feat/admission-clock", openPull: 190 },
  { repo: "Conduit", name: "codex/add-event-stream-manager-module", openPull: 119 },
  { repo: "Conduit", name: "codex/refactor-schema-ddl-into-migration-modules", openPull: 120 },
  { repo: "Conduit", name: "counsel/db-tls-verify", openPull: 155 },
  { repo: "Conduit", name: "harden/ssl-and-signed-cursors", openPull: 162 },
  { repo: "Conduit", name: "bolt-optimize-cursor-validation-task-filter-construction-11315320121705202538", openPull: 188 },
  { repo: "Resonance", name: "main", openPull: null },
  { repo: "Resonance", name: "feat/cutover-lattice-1000", openPull: 154 },
  { repo: "Resonance", name: "feat/chamber-dissolve-guard", openPull: 157 },
  { repo: "QuicksilverV1", name: "main", openPull: null },
  { repo: "QuicksilverV1", name: "feat/cutover-lattice-1000", openPull: 242 },
  { repo: "QuicksilverV1", name: "dependabot/github_actions/actions-640176b5ab", openPull: 209 },
];

describe("14:00 EDT audit hardening", () => {
  it("stays on phase 0 and prunes nothing", () => {
    const decision = evaluateAudit(probe, liveRefs);
    expect(decision.revision).toBe("2026-10-09-audit-hardening");
    expect(decision.currentPhase).toBe(0);
    expect(decision.stampIsNotAdvance).toBe(true);
    expect(decision.entropySatisfied).toBe(true);
    expect(decision.pruneThisPass).toEqual([]);
    expect(decision.secretInvented).toBe(false);
    expect(decision.discretionaryByRepo.Conduit).toBe(2);
    expect(decision.discretionaryByRepo.Resonance).toBe(2);
    expect(decision.discretionaryByRepo.QuicksilverV1).toBe(1);
    expect(decision.holdNotDelete).toContain("release/0.8.0");
    expect(decision.notMerged).toContain(187);
  });

  it("treats an orphan ref as the only prune target", () => {
    const decision = evaluateAudit(probe, [...liveRefs, { repo: "Conduit", name: "hygiene/orphan-fence", openPull: null }]);
    expect(decision.pruneThisPass).toEqual(["Conduit:hygiene/orphan-fence"]);
    expect(decision.entropySatisfied).toBe(false);
  });

  it("refuses a pruned-fence reopen, a hold delete, and a stamp that clears phase 0", () => {
    const decision = evaluateAudit(probe, liveRefs, "feat/pause-before-secret");
    expect(decision.reopenRefusal).toMatch(/pruned fence/);
    expect(() => evaluateAudit(probe, liveRefs, "release/0.8.0")).toThrow(/hold ref/);
    expect(() => assertStampDoesNotClearOwner(0, 3)).toThrow(/owner gate/);
    expect(HOLD_NOT_DELETE).toContain("feat/chamber-dissolve-guard");
  });
});
