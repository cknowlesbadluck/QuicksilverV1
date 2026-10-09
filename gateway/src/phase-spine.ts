/**
 * Phase spine. Executable 10-phase lock for the 13:00 EDT 2026-10-09 pass.
 *
 * Pure. Does not call hosts, invent secrets, merge pulls, or delete refs.
 * Callers delete only names this module returns as executed prune targets.
 * A pruned fence name must not be reopened as a new witness family.
 */

export const PHASE_SPINE_REVISION = "2026-10-09-phase-spine";

export const PRUNED_FENCE_BRANCHES = [
  "feat/pause-before-secret",
  "feat/phase-admission-1000",
  "hygiene/platform-drift-fence",
  "hygiene/chunk-advisory-fence",
  "hygiene/roadmap-1200-refresh",
] as const;

export type PhaseState = "blocked" | "open" | "satisfied";

export type SpinePhase = {
  id: number;
  name: string;
  state: PhaseState;
  exit: string;
};

export type SpineProbe = {
  resonanceReady: number;
  missingRequired: string[];
  readyOmitsOwnerFields: boolean;
  supabaseInactive: string[];
  vercelClass: "alias_absent" | "alias_present" | "other";
  deviceGateRecorded: boolean;
  persistenceProven: boolean;
};

export type SpineDecision = {
  revision: string;
  currentPhase: number;
  phases: SpinePhase[];
  pruneExecuted: string[];
  holdNotDelete: string[];
  reopenRefusal: string | null;
  secretInvented: false;
};

const REQUIRED_SECRET = "SUPABASE_SERVICE_ROLE_KEY";

export function evaluateSpine(probe: SpineProbe, attemptedBranch: string | null = null): SpineDecision {
  if (probe.missingRequired.includes(REQUIRED_SECRET) === false && probe.resonanceReady !== 200) {
    throw new Error("refusing a ready body that dropped the owner key without becoming ready");
  }
  const ownerBlocked =
    probe.supabaseInactive.length > 0 || probe.missingRequired.includes(REQUIRED_SECRET);
  const phases: SpinePhase[] = [
    {
      id: 0,
      name: "Owner gate",
      state: ownerBlocked ? "blocked" : "satisfied",
      exit: "Unpause Resonance Supabase, then set the service-role key on Netlify resonancenexus only. Public GET /api/ready is 200.",
    },
    {
      id: 1,
      name: "Entropy collapse",
      state: "satisfied",
      exit: "Discretionary open pulls stay at or under 2 per active repo. Automation holds do not count. Orphan fence branches are pruned.",
    },
    {
      id: 2,
      name: "Ready parity",
      state:
        probe.resonanceReady === 503 &&
        probe.missingRequired.length === 1 &&
        probe.missingRequired[0] === REQUIRED_SECRET &&
        probe.readyOmitsOwnerFields &&
        probe.vercelClass === "alias_absent"
          ? "satisfied"
          : "blocked",
      exit: "Public Netlify ready body matches the known 503 contract. A Vercel alias 404 is alias_absent, not a product failure.",
    },
    {
      id: 3,
      name: "Persistence proof",
      state: ownerBlocked || !probe.persistenceProven ? "blocked" : "satisfied",
      exit: "Apply supabase/migrations on the unpaused Resonance project and smoke resonancenexus.",
    },
    {
      id: 4,
      name: "Idempotent execution",
      state: "blocked",
      exit: "Idempotency-Key replay does not double-write on the production host.",
    },
    {
      id: 5,
      name: "Adapter substitution",
      state: "blocked",
      exit: "A second provider satisfies the same capability contract. Conduit stays project-agnostic.",
    },
    {
      id: 6,
      name: "Chamber lifecycle",
      state: "blocked",
      exit: "Form, work, dissolve, audit intact. Watch cannot dissolve. Dissonance can. Durable evidence waits on phase 3.",
    },
    {
      id: 7,
      name: "iOS peer contract",
      state: "blocked",
      exit: "One capability model on web and iOS. Do not revive closed cockpit pulls.",
    },
    {
      id: 8,
      name: "Device acceptance",
      state: probe.deviceGateRecorded ? "satisfied" : "blocked",
      exit: "Owner records the iPhone 16e human gate. A merged device-fence pull is not this exit.",
    },
    {
      id: 9,
      name: "Release hardening",
      state: "blocked",
      exit: "SideStore IPA evidence and Postgres TLS only after the owner sets Render env. release/0.8.0 stays. Keep-red stays unmerged.",
    },
  ];
  const current = phases.find((phase) => phase.state === "blocked") ?? phases[phases.length - 1];
  const reopenRefusal =
    attemptedBranch !== null &&
    (PRUNED_FENCE_BRANCHES as readonly string[]).includes(attemptedBranch)
      ? `refusing to reopen pruned fence branch ${attemptedBranch}`
      : null;
  return {
    revision: PHASE_SPINE_REVISION,
    currentPhase: current.id,
    phases,
    pruneExecuted: [...PRUNED_FENCE_BRANCHES],
    holdNotDelete: ["release/0.8.0", "feat/cutover-lattice-1000", "feat/admission-clock", "feat/chamber-dissolve-guard"],
    reopenRefusal,
    secretInvented: false,
  };
}
