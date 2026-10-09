/**
 * Phase governor.
 *
 * Pure. Does not call hosts, invent secrets, merge pulls, or delete branches.
 * Callers pass already-observed facts. The governor maps those facts onto the
 * ten-phase portfolio roadmap and refuses every advance that still needs the owner.
 */

export const PHASE_GOVERNOR_REVISION = "2026-10-09-phase-governor";

export const KEEP_RED = [119, 120, 155, 162] as const;

export type Probe = {
  conduitHealth: number;
  conduitReady: number;
  conduitVersion: string;
  contractRevision: string;
  persistence: string;
  diagnosticsOk: boolean;
  resonanceReady: number;
  missingRequired: string[];
  readyBodyOmitsOwnerAction: boolean;
  vercelStatus: number;
  vercelClass: "alias_absent" | "alias_present" | "other";
  supabasePaused: boolean;
  deviceGateRecorded: boolean;
  persistenceProven: boolean;
  discretionaryOpen: { conduit: number; resonance: number; quicksilver: number };
  activityPruned: number;
};

export type PhaseState = "blocked" | "open" | "satisfied";

export type Phase = {
  id: number;
  name: string;
  state: PhaseState;
  exit: string;
  blocker: string | null;
};

export type BranchFact = {
  repo: string;
  name: string;
  openPull: number | null;
  divergedRelease: boolean;
};

export type PruneDisposition = "hold_default" | "hold_open_pr" | "hold_diverged" | "delete_candidate";

export type GovernorDecision = {
  revision: string;
  currentPhase: number;
  phases: Phase[];
  agentMay: string[];
  agentMustNot: string[];
  ownerMust: string[];
  prune: Array<BranchFact & { disposition: PruneDisposition }>;
  deleteCandidates: string[];
};

const REQUIRED_SECRET = "SUPABASE_SERVICE_ROLE_KEY";

export function evaluatePhases(probe: Probe): Phase[] {
  const readyKnown =
    (probe.resonanceReady === 503 &&
      probe.missingRequired.length === 1 &&
      probe.missingRequired[0] === REQUIRED_SECRET &&
      probe.readyBodyOmitsOwnerAction) ||
    (probe.resonanceReady === 200 && probe.missingRequired.length === 0);
  const conduitUp =
    probe.conduitHealth === 200 &&
    probe.conduitReady === 200 &&
    probe.conduitVersion === "0.8.0" &&
    probe.contractRevision === "2026-10-03-ready-surface" &&
    probe.persistence === "postgres" &&
    probe.diagnosticsOk;
  const entropyOk =
    probe.discretionaryOpen.conduit <= 2 &&
    probe.discretionaryOpen.resonance <= 2 &&
    probe.discretionaryOpen.quicksilver <= 2;
  const ownerBlocked = probe.supabasePaused || probe.missingRequired.includes(REQUIRED_SECRET);
  const phase0: Phase = {
    id: 0,
    name: "Owner gate",
    state: ownerBlocked ? "blocked" : "satisfied",
    exit: "Unpause Resonance Supabase, then set the service-role key on Netlify resonancenexus only. Public GET /api/ready is 200.",
    blocker: probe.supabasePaused
      ? "Supabase project paused"
      : probe.missingRequired.includes(REQUIRED_SECRET)
        ? `missing ${REQUIRED_SECRET}`
        : null,
  };
  const afterOwner = (id: number, name: string, exit: string, proven: boolean, ownBlocker: string): Phase => ({
    id,
    name,
    state: ownerBlocked ? "blocked" : proven ? "satisfied" : "blocked",
    exit,
    blocker: ownerBlocked ? "Phase 0 owner gate" : proven ? null : ownBlocker,
  });
  return [
    phase0,
    {
      id: 1,
      name: "Entropy collapse",
      state: entropyOk ? "satisfied" : "blocked",
      exit: "Discretionary open pulls stay at or under 2 per active repo. Automation holds do not count.",
      blocker: entropyOk ? null : "discretionary open count above 2",
    },
    {
      id: 2,
      name: "Ready parity",
      state: conduitUp && readyKnown && probe.vercelClass === "alias_absent" ? "satisfied" : "blocked",
      exit: "Public Netlify ready body matches the repository contract. A Vercel alias success does not count.",
      blocker: readyKnown ? null : "ready body drifted or secret missing in an unexpected shape",
    },
    afterOwner(3, "Persistence proof", "Apply supabase/migrations on the unpaused project and smoke resonancenexus.", probe.persistenceProven, "migrations not proven on the unpaused project"),
    afterOwner(4, "Idempotent execution", "Idempotency-Key replay does not double-write on the production host.", false, "production replay not proven"),
    afterOwner(5, "Adapter substitution", "A second provider satisfies the same capability contract. Conduit stays project-agnostic.", false, "second provider not proven"),
    afterOwner(6, "Chamber lifecycle", "Form, work, dissolve, audit intact. Durable evidence waits on Phase 3.", false, "chamber dissolve audit not proven on durable evidence"),
    afterOwner(7, "iOS peer contract", "One capability model on web and iOS. Do not revive closed cockpit pulls.", false, "single capability model not proven"),
    afterOwner(8, "Device acceptance", "Owner records the iPhone 16e human gate. A merged device-fence pull is not this exit.", probe.deviceGateRecorded, "device HG unrecorded"),
    afterOwner(9, "Release hardening", "SideStore IPA evidence and Postgres TLS only after the owner sets Render env. Keep-red stays unmerged until then.", false, "Render TLS env and IPA evidence unset"),
  ];
}

export function classifyBranch(branch: BranchFact): PruneDisposition {
  if (branch.name === "main" || branch.name === "master") return "hold_default";
  if (branch.divergedRelease || branch.name.startsWith("release/")) return "hold_diverged";
  if (branch.openPull !== null) return "hold_open_pr";
  return "delete_candidate";
}

export function decide(probe: Probe, branches: BranchFact[]): GovernorDecision {
  const phases = evaluatePhases(probe);
  const current = phases.find((phase) => phase.state === "blocked") ?? phases[phases.length - 1];
  const prune = branches.map((branch) => ({ ...branch, disposition: classifyBranch(branch) }));
  return {
    revision: PHASE_GOVERNOR_REVISION,
    currentPhase: current.id,
    phases,
    agentMay: [
      "refresh the open cutover lattice in place",
      "run activity_prune",
      "classify branches and refuse protected deletes",
    ],
    agentMustNot: [
      "invent SUPABASE_SERVICE_ROLE_KEY",
      "merge keep-red 119 120 155 162",
      "merge lattice while the owner gate is open",
      "merge automation holds while checks are unstable",
      "delete release/0.8.0",
      "open a new witness pull",
      "treat a Vercel alias 404 as a Resonance failure mode other than alias_absent",
    ],
    ownerMust: [
      "unpause Resonance Supabase",
      "set SUPABASE_SERVICE_ROLE_KEY on Netlify resonancenexus only",
      "record device HG on iPhone 16e",
    ],
    prune,
    deleteCandidates: prune.filter((row) => row.disposition === "delete_candidate").map((row) => `${row.repo}:${row.name}`),
  };
}
