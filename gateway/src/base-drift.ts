export const BASE_DRIFT_REVISION = "2026-10-09-base-drift";

export const HOLD_NOT_DELETE = [
  "release/0.8.0",
  "feat/cutover-lattice-1000",
  "feat/admission-clock",
  "feat/chamber-dissolve-guard",
  "codex/add-event-stream-manager-module",
  "codex/refactor-schema-ddl-into-migration-modules",
  "counsel/db-tls-verify",
  "harden/ssl-and-signed-cursors",
  "bolt-optimize-cursor-validation-task-filter-construction-11315320121705202538",
  "dependabot/github_actions/actions-640176b5ab",
] as const;

export const NOT_MERGE = [119, 120, 155, 162, 187, 188, 190, 154, 157, 242, 209] as const;

export const PRUNED_FENCE_BRANCHES = [
  "feat/pause-before-secret",
  "feat/phase-admission-1000",
  "hygiene/platform-drift-fence",
  "hygiene/chunk-advisory-fence",
  "hygiene/roadmap-1200-refresh",
] as const;

export const PHASES = [
  { id: 0, name: "Owner gate", exit: "Unpause Resonance Supabase, set SUPABASE_SERVICE_ROLE_KEY on Netlify resonancenexus only, and record device HG on iPhone 16e." },
  { id: 1, name: "Lattice current", exit: "Cutover lattice branches contain main. Dirty base is not a merge." },
  { id: 2, name: "Ready parity", exit: "Resonance /api/ready is 200 and still omits invented owner fields." },
  { id: 3, name: "Persistence proof", exit: "Migrations applied on the unpaused Resonance project and smoked." },
  { id: 4, name: "Idempotent execution", exit: "Idempotency-Key replay does not double-write on the production host." },
  { id: 5, name: "Adapter substitution", exit: "A second provider satisfies the same capability contract. Conduit stays project-agnostic." },
  { id: 6, name: "Chamber lifecycle", exit: "Form, work, dissolve, audit intact. Watch cannot dissolve." },
  { id: 7, name: "iOS peer contract", exit: "One capability model on web and iOS. Closed cockpit pulls stay closed." },
  { id: 8, name: "Device acceptance", exit: "HG recorded on iPhone 16e. Simulator CI and gateway health are not this exit." },
  { id: 9, name: "Release surface", exit: "Privacy manifest, SideStore evidence, and deny-by-default grants still hold." },
] as const;

export type LatticeDrift = {
  repo: string;
  pull: number;
  baseSha: string;
  mainSha: string;
  behind: number;
  conflictFiles: string[];
};

export type DriftProbe = {
  resonanceReady: number;
  missingRequired: string[];
  readyOmitsOwnerFields: boolean;
  supabaseInactive: string[];
  vercelClass: "alias_absent";
  deviceGateRecorded: boolean;
  secretInvented: false;
};

export type DriftDecision = {
  revision: typeof BASE_DRIFT_REVISION;
  currentPhase: 0;
  stampIsNotAdvance: true;
  stabilization: "branch_contains_main";
  driftBefore: LatticeDrift[];
  conflictFile: "docs/PORTFOLIO-ROADMAP-10-PHASE.md";
  pullMerged: false;
  pruneThisPass: [];
  holdNotDelete: readonly string[];
  notMerged: readonly number[];
  ownerActions: string[];
  secretInvented: false;
};

const OBSERVED_DRIFT: LatticeDrift[] = [
  { repo: "Conduit", pull: 187, baseSha: "771797c", mainSha: "40aeb11", behind: 1, conflictFiles: ["docs/PORTFOLIO-ROADMAP-10-PHASE.md"] },
  { repo: "Resonance", pull: 154, baseSha: "96b7f56", mainSha: "278bc39", behind: 1, conflictFiles: ["docs/PORTFOLIO-ROADMAP-10-PHASE.md"] },
  { repo: "QuicksilverV1", pull: 242, baseSha: "182d133", mainSha: "8bc9b57", behind: 2, conflictFiles: ["docs/PORTFOLIO-ROADMAP-10-PHASE.md"] },
];

export function evaluateBaseDrift(probe: DriftProbe): DriftDecision {
  if (probe.secretInvented !== false) {
    throw new Error("refusing to invent a secret");
  }
  if (probe.resonanceReady !== 503 || probe.missingRequired.join(",") !== "SUPABASE_SERVICE_ROLE_KEY") {
    throw new Error("owner gate facts changed; do not stamp phase 0 closed");
  }
  if (!probe.readyOmitsOwnerFields || probe.deviceGateRecorded || probe.vercelClass !== "alias_absent") {
    throw new Error("probe no longer matches the 15:00 EDT owner gate");
  }
  return {
    revision: BASE_DRIFT_REVISION,
    currentPhase: 0,
    stampIsNotAdvance: true,
    stabilization: "branch_contains_main",
    driftBefore: OBSERVED_DRIFT,
    conflictFile: "docs/PORTFOLIO-ROADMAP-10-PHASE.md",
    pullMerged: false,
    pruneThisPass: [],
    holdNotDelete: HOLD_NOT_DELETE,
    notMerged: NOT_MERGE,
    ownerActions: [
      "Unpause Resonance Supabase, then set SUPABASE_SERVICE_ROLE_KEY on Netlify resonancenexus only.",
      "Record device HG on iPhone 16e. A merged device-fence pull is not this exit.",
    ],
    secretInvented: false,
  };
}

export function assertStampDoesNotClearOwner(beforePhase: number, afterPhase: number): void {
  if (beforePhase === 0 && afterPhase !== 0) {
    throw new Error("a stamp cannot clear the owner gate");
  }
}

export function assertHoldNotDeleted(name: string): void {
  if ((HOLD_NOT_DELETE as readonly string[]).includes(name) || (PRUNED_FENCE_BRANCHES as readonly string[]).includes(name)) {
    throw new Error(`refusing to prune ${name}`);
  }
}
