import { describe, expect, it } from "vitest";
import { KEEP_RED } from "../src/phase-lock";
import { CANONICAL_HEAD, buildCollapseReceipt, type CollapsePull } from "../src/collapse-receipt";

const live: CollapsePull[] = [
  { repo: "Conduit", number: 187, title: "feat: portfolio cutover lattice", headRef: CANONICAL_HEAD },
  { repo: "Conduit", number: 185, title: "feat: entropy governor for witness budget and keep-red", headRef: "harden/entropy-governor-2300" },
  { repo: "Conduit", number: 183, title: "feat: project-agnostic work admission gate", headRef: "harden/work-admission-1900" },
  { repo: "Conduit", number: 182, title: "feat: project-agnostic degrade planner", headRef: "feat/degrade-planner-0700" },
  { repo: "Conduit", number: 180, title: "feat: project-agnostic phase clock", headRef: "harden/phase-clock-0001" },
  { repo: "Conduit", number: 162, title: "harden: shared Postgres TLS policy and optional HMAC cursors", headRef: "harden/ssl-and-signed-cursors" },
  { repo: "Conduit", number: 155, title: "DB TLS: verify Postgres certificates by default", headRef: "counsel/db-tls-verify" },
  { repo: "Conduit", number: 120, title: "DRAFT KEEP RED: Add explicit ordered database migrations", headRef: "codex/refactor-schema-ddl-into-migration-modules" },
  { repo: "Conduit", number: 119, title: "DRAFT KEEP RED: Add managed SSE admission and graceful shutdown", headRef: "codex/add-event-stream-manager-module" },
  { repo: "Resonance", number: 154, title: "feat: portfolio cutover lattice", headRef: CANONICAL_HEAD },
  { repo: "Resonance", number: 153, title: "feat: entropy governor for witness budget and keep-red", headRef: "harden/entropy-governor-2300" },
  { repo: "Resonance", number: 151, title: "feat: degrade planner for host probes", headRef: "feat/degrade-planner-0700" },
  { repo: "Resonance", number: 150, title: "feat: pin public ready body to the owner-gate contract", headRef: "chore/public-ready-pin" },
  { repo: "QuicksilverV1", number: 242, title: "feat: portfolio cutover lattice", headRef: CANONICAL_HEAD },
  { repo: "QuicksilverV1", number: 241, title: "feat: refuse device acceptance on gateway health", headRef: "feat/device-acceptance-1600" },
  { repo: "QuicksilverV1", number: 240, title: "feat: entropy governor for witness budget and keep-red", headRef: "harden/entropy-governor-2300" },
  { repo: "QuicksilverV1", number: 238, title: "feat: degrade planner for host probes and gateway errors", headRef: "feat/degrade-planner-0700" },
  { repo: "QuicksilverV1", number: 209, title: "chore(deps): bump actions/checkout from 4 to 7 in the actions group", headRef: "dependabot/github_actions/actions-640176b5ab" },
];

describe("collapse receipt", () => {
  it("closes only superseded families and never deletes keep-red or canonical heads", () => {
    const receipt = buildCollapseReceipt(live, true);
    expect(receipt.revision).toBe("2026-10-08-2300-collapse");
    expect(receipt.openNewWitness).toBe(false);
    expect(receipt.inventSecret).toBe(false);
    expect(receipt.mergeKeepRed).toBe(false);
    expect(receipt.close.map((row) => row.number).sort((a, b) => a - b)).toEqual([
      150, 151, 153, 180, 182, 183, 185, 238, 240,
    ]);
    expect(receipt.deleteHeads.some((row) => row.headRef === CANONICAL_HEAD)).toBe(false);
    for (const number of KEEP_RED) {
      expect(receipt.close.some((row) => row.number === number)).toBe(false);
    }
    expect(receipt.hold.some((row) => row.number === 241)).toBe(true);
    expect(receipt.hold.some((row) => row.number === 209)).toBe(true);
    expect(receipt.forbidden.some((item) => item.includes("Do not invent"))).toBe(true);
  });

  it("refuses a keep-red number even when the title looks superseded", () => {
    const receipt = buildCollapseReceipt([
      { repo: "Conduit", number: 119, title: "feat: entropy governor keep red", headRef: "codex/add-event-stream-manager-module" },
      { repo: "Conduit", number: 187, title: "feat: portfolio cutover lattice", headRef: CANONICAL_HEAD },
    ], true);
    expect(receipt.close).toEqual([]);
    expect(receipt.deleteHeads).toEqual([]);
  });
});
