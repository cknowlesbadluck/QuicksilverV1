/**
 * Portfolio cutover lattice.
 *
 * Pure decision function. It does not call hosts, invent secrets, merge pull
 * requests, or archive repositories. Callers pass already-observed facts.
 *
 * The lattice admits exactly one next action. Later phases stay closed while
 * an owner gate or an entropy breach is open.
 */

export const LATTICE_REVISION = "2026-10-08-cutover-lattice";

export const OPEN_PR_BUDGET = 2;

export type HostClass =
  | "ready"
  | "owner_gated"
  | "alias_absent"
  | "unprobed"
  | "unexpected";

export type PhaseId =
  | "p0_owner_gates"
  | "p1_entropy_collapse"
  | "p2_ready_parity"
  | "p3_persistence_proof"
  | "p4_idempotent_execution"
  | "p5_adapter_substitution"
  | "p6_chamber_lifecycle"
  | "p7_ios_peer_contract"
  | "p8_device_acceptance"
  | "p9_release_hardening";

export type Admission = "owner_only" | "implement" | "blocked" | "hold";

export type HostProbe = {
  name: string;
  httpStatus: number | null;
  missingRequired?: string[];
  bodyHasOwnerActionRequired?: boolean;
  bodyHasContractRevision?: boolean;
  deploymentNotFound?: boolean;
};

export type RepoEntropy = {
  repo: string;
  openPullRequests: number;
  keepRed: number;
};

export type LatticeInput = {
  hosts: HostProbe[];
  repos: RepoEntropy[];
  persistenceProof?: boolean;
  readyParityProof?: boolean;
  executionProof?: boolean;
  adapterSubstitutionProof?: boolean;
  chamberProof?: boolean;
  iosContractProof?: boolean;
  deviceAcceptanceProof?: boolean;
  releaseEvidence?: boolean;
};

export type LatticeDecision = {
  revision: string;
  admittedPhase: PhaseId;
  admission: Admission;
  reason: string;
  ownerActions: string[];
  refusedPhases: PhaseId[];
  entropyBreach: boolean;
};

export const PHASES: readonly PhaseId[] = [
  "p0_owner_gates",
  "p1_entropy_collapse",
  "p2_ready_parity",
  "p3_persistence_proof",
  "p4_idempotent_execution",
  "p5_adapter_substitution",
  "p6_chamber_lifecycle",
  "p7_ios_peer_contract",
  "p8_device_acceptance",
  "p9_release_hardening",
];

const OWNER_SECRET = "SUPABASE_SERVICE_ROLE_KEY";

export function classifyHost(probe: HostProbe): HostClass {
  if (probe.httpStatus === null) return "unprobed";
  if (probe.deploymentNotFound || probe.httpStatus === 404) return "alias_absent";
  if (probe.httpStatus === 200) return "ready";
  const missing = probe.missingRequired ?? [];
  if (probe.httpStatus === 503 && missing.length > 0) return "owner_gated";
  return "unexpected";
}

export function ownerGateOpen(hosts: HostProbe[]): boolean {
  return hosts.some((host) => {
    const missing = host.missingRequired ?? [];
    return missing.includes(OWNER_SECRET) || classifyHost(host) === "owner_gated";
  });
}

export function publicContractDrift(hosts: HostProbe[]): boolean {
  return hosts.some((host) => {
    if (classifyHost(host) !== "owner_gated") return false;
    return host.bodyHasOwnerActionRequired === true || host.bodyHasContractRevision === true;
  });
}

export function entropyBreach(repos: RepoEntropy[]): boolean {
  return repos.some((repo) => repo.openPullRequests > OPEN_PR_BUDGET);
}

export function decideCutover(input: LatticeInput): LatticeDecision {
  const ownerActions: string[] = [];
  const resonanceGated = input.hosts.some((host) => (host.missingRequired ?? []).includes(OWNER_SECRET));
  if (resonanceGated) {
    ownerActions.push("Set SUPABASE_SERVICE_ROLE_KEY on Netlify resonancenexus only. Do not invent it.");
  }
  if (input.hosts.some((host) => classifyHost(host) === "alias_absent")) {
    ownerActions.push("Treat resonancenexus.vercel.app 404 DEPLOYMENT_NOT_FOUND as alias_absent, not an owner gate.");
  }
  ownerActions.push("Archive cknowlesbadluck/Quicksilver. Agent archive attempts return 403.");
  ownerActions.push("Device acceptance remains an iPhone 16e human gate. Simulator CI is not that gate.");

  const refused = (admitted: PhaseId): PhaseId[] => PHASES.filter((phase) => phase !== admitted);

  if (ownerGateOpen(input.hosts) || publicContractDrift(input.hosts)) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p0_owner_gates",
      admission: "owner_only",
      reason: publicContractDrift(input.hosts)
        ? "Public ready body drifted: ownerActionRequired or contractRevision must stay omitted until the owner key is set."
        : "Owner gate is open. Later phases are refused until the missing key is set by the owner.",
      ownerActions,
      refusedPhases: refused("p0_owner_gates"),
      entropyBreach: entropyBreach(input.repos),
    };
  }

  if (entropyBreach(input.repos)) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p1_entropy_collapse",
      admission: "implement",
      reason: `Open pull requests exceed the budget of ${OPEN_PR_BUDGET} per repository. Collapse or keep-red before new scope.`,
      ownerActions,
      refusedPhases: refused("p1_entropy_collapse"),
      entropyBreach: true,
    };
  }

  if (!input.readyParityProof) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p2_ready_parity",
      admission: "implement",
      reason: "Owner gate is closed and entropy is inside budget. Next proof is ready-contract parity.",
      ownerActions,
      refusedPhases: refused("p2_ready_parity"),
      entropyBreach: false,
    };
  }

  if (!input.persistenceProof) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p3_persistence_proof",
      admission: "implement",
      reason: "Ready parity is proved. Persistence migrations are next. Do not invent the service-role key.",
      ownerActions,
      refusedPhases: refused("p3_persistence_proof"),
      entropyBreach: false,
    };
  }

  if (!input.executionProof) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p4_idempotent_execution",
      admission: "implement",
      reason: "Persistence is proved. Idempotent execution is next. Do not open a second adapter yet.",
      ownerActions,
      refusedPhases: refused("p4_idempotent_execution"),
      entropyBreach: false,
    };
  }

  if (!input.adapterSubstitutionProof) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p5_adapter_substitution",
      admission: "implement",
      reason: "Execution proof exists. Provider substitution is the next product proof.",
      ownerActions,
      refusedPhases: refused("p5_adapter_substitution"),
      entropyBreach: false,
    };
  }

  if (!input.chamberProof) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p6_chamber_lifecycle",
      admission: "implement",
      reason: "Substitution is proved. Chamber form, work, dissolve, and audit are next.",
      ownerActions,
      refusedPhases: refused("p6_chamber_lifecycle"),
      entropyBreach: false,
    };
  }

  if (!input.iosContractProof) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p7_ios_peer_contract",
      admission: "implement",
      reason: "Chamber proof exists. Next is one capability model on web and iOS.",
      ownerActions,
      refusedPhases: refused("p7_ios_peer_contract"),
      entropyBreach: false,
    };
  }

  if (!input.deviceAcceptanceProof) {
    return {
      revision: LATTICE_REVISION,
      admittedPhase: "p8_device_acceptance",
      admission: "owner_only",
      reason: "Native contract is recorded. Device acceptance is an iPhone 16e human gate, not simulator CI.",
      ownerActions,
      refusedPhases: refused("p8_device_acceptance"),
      entropyBreach: false,
    };
  }

  return {
    revision: LATTICE_REVISION,
    admittedPhase: "p9_release_hardening",
    admission: input.releaseEvidence ? "hold" : "implement",
    reason: input.releaseEvidence
      ? "Release evidence is recorded. Hold for adversarial review. Do not open a new phase."
      : "Device acceptance is recorded. Release hardening is next: SideStore IPA evidence, privacy manifest, and TLS only after owner env.",
    ownerActions,
    refusedPhases: refused("p9_release_hardening"),
    entropyBreach: false,
  };
}
