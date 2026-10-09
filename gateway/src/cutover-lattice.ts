/**
 * Portfolio cutover lattice. Same decision as Conduit and Resonance.
 * It does not call hosts, invent secrets, or merge pull requests.
 * A paused Supabase project is an owner gate distinct from a missing key.
 * A merged device fence is not device acceptance.
 */

import { DEVICE_FENCE_LANDED, classifyLanded, holdContradictions } from "./landed-fence";

export const LATTICE_REVISION = "2026-10-09-landed-fence";
export const OPEN_PR_BUDGET = 2;
export type HostClass = "ready" | "owner_gated" | "project_paused" | "alias_absent" | "unprobed" | "unexpected";
export type PhaseId = "p0_owner_gates" | "p1_entropy_collapse" | "p2_ready_parity" | "p3_persistence_proof" | "p4_idempotent_execution" | "p5_adapter_substitution" | "p6_chamber_lifecycle" | "p7_ios_peer_contract" | "p8_device_acceptance" | "p9_release_hardening";
export type Admission = "owner_only" | "implement" | "blocked" | "hold";
export type HostProbe = { name: string; httpStatus: number | null; missingRequired?: string[]; bodyHasOwnerActionRequired?: boolean; bodyHasContractRevision?: boolean; deploymentNotFound?: boolean; projectPaused?: boolean };
export type RepoEntropy = { repo: string; openPullRequests: number; keepRed: number; archived?: boolean };
export type LatticeInput = { hosts: HostProbe[]; repos: RepoEntropy[]; legacyQuicksilverArchived?: boolean; latticeFamilyOpen?: boolean; persistenceProof?: boolean; readyParityProof?: boolean; executionProof?: boolean; adapterSubstitutionProof?: boolean; chamberProof?: boolean; iosContractProof?: boolean; deviceAcceptanceProof?: boolean; releaseEvidence?: boolean; openPullNumbers?: number[] };
export type LatticeDecision = { revision: string; admittedPhase: PhaseId; admission: Admission; reason: string; ownerActions: string[]; refusedPhases: PhaseId[]; entropyBreach: boolean; discretionaryOpen: number; refreshInPlace: boolean; deviceFence: "landed_unverified" | "landed_accepted" };
export const PHASES: readonly PhaseId[] = ["p0_owner_gates","p1_entropy_collapse","p2_ready_parity","p3_persistence_proof","p4_idempotent_execution","p5_adapter_substitution","p6_chamber_lifecycle","p7_ios_peer_contract","p8_device_acceptance","p9_release_hardening"];
const OWNER_SECRET = "SUPABASE_SERVICE_ROLE_KEY";
export function classifyHost(probe: HostProbe): HostClass {
  if (probe.projectPaused) return "project_paused";
  if (probe.httpStatus === null) return "unprobed";
  if (probe.deploymentNotFound || probe.httpStatus === 404) return "alias_absent";
  if (probe.httpStatus === 200) return "ready";
  if (probe.httpStatus === 503 && (probe.missingRequired ?? []).length > 0) return "owner_gated";
  return "unexpected";
}
export function discretionaryOpen(repo: RepoEntropy): number {
  if (repo.archived) return 0;
  return Math.max(0, repo.openPullRequests - Math.max(0, repo.keepRed));
}
export function entropyBreach(repos: RepoEntropy[]): boolean {
  return repos.some((repo) => discretionaryOpen(repo) > OPEN_PR_BUDGET);
}
function ownerGateOpen(hosts: HostProbe[]): boolean {
  return hosts.some((host) => (host.missingRequired ?? []).includes(OWNER_SECRET) || classifyHost(host) === "owner_gated" || classifyHost(host) === "project_paused");
}
function publicContractDrift(hosts: HostProbe[]): boolean {
  return hosts.some((host) => classifyHost(host) === "owner_gated" && (host.bodyHasOwnerActionRequired === true || host.bodyHasContractRevision === true));
}
function ownerActionsFor(input: LatticeInput): string[] {
  const ownerActions: string[] = [];
  const paused = input.hosts.filter((host) => host.projectPaused).map((host) => host.name);
  if (paused.length > 0) ownerActions.push(`Unpause Supabase project(s) ${paused.join(", ")} before setting any key. A paused project cannot prove persistence.`);
  if (input.hosts.some((host) => (host.missingRequired ?? []).includes(OWNER_SECRET))) ownerActions.push("Set SUPABASE_SERVICE_ROLE_KEY on Netlify resonancenexus only. Do not invent it.");
  if (input.hosts.some((host) => classifyHost(host) === "alias_absent")) ownerActions.push("Treat resonancenexus.vercel.app 404 DEPLOYMENT_NOT_FOUND as alias_absent, not an owner gate.");
  ownerActions.push(input.legacyQuicksilverArchived === false ? "Archive cknowlesbadluck/Quicksilver. Do not retry a 403 as if it were success." : "Legacy cknowlesbadluck/Quicksilver is archived. Do not retry archive.");
  ownerActions.push("QuicksilverV1 #241 is on main at 83f13504. That merge is landed_unverified. iPhone 16e device acceptance is still unrecorded.");
  ownerActions.push("Keep-red Conduit #119 #120 #155 #162 stay unmerged until the owner sets Render Postgres TLS env.");
  return ownerActions;
}
export function decideCutover(input: LatticeInput): LatticeDecision {
  const ownerActions = ownerActionsFor(input);
  const refused = (admitted: PhaseId): PhaseId[] => PHASES.filter((phase) => phase !== admitted);
  const discretionary = input.repos.reduce((sum, repo) => sum + discretionaryOpen(repo), 0);
  const refreshInPlace = input.latticeFamilyOpen === true;
  const breach = entropyBreach(input.repos);
  const paused = input.hosts.some((host) => host.projectPaused);
  const deviceFence = classifyLanded({ ...DEVICE_FENCE_LANDED, deviceRecorded: input.deviceAcceptanceProof === true });
  const contradictions = holdContradictions(input.openPullNumbers ?? [], [DEVICE_FENCE_LANDED]);
  if (contradictions.length > 0) throw new Error(`refusing to hold landed pull(s) ${contradictions.join(", ")} as open`);
  const finish = (admittedPhase: PhaseId, admission: Admission, reason: string): LatticeDecision => ({
    revision: LATTICE_REVISION,
    admittedPhase,
    admission: refreshInPlace && admission === "implement" ? "hold" : admission,
    reason: refreshInPlace && admission === "implement" ? `${reason} Lattice family is already open. Refresh in place. Do not open a new witness pull.` : reason,
    ownerActions,
    refusedPhases: refused(admittedPhase),
    entropyBreach: breach,
    discretionaryOpen: discretionary,
    refreshInPlace,
    deviceFence,
  });
  if (ownerGateOpen(input.hosts) || publicContractDrift(input.hosts)) return finish("p0_owner_gates", "owner_only", paused ? "Owner gate is open. Supabase project pause blocks persistence even after the Netlify key is set." : publicContractDrift(input.hosts) ? "Public ready body drifted: ownerActionRequired or contractRevision must stay omitted until the owner key is set." : "Owner gate is open. Later phases are refused until the missing key is set by the owner.");
  if (breach) return finish("p1_entropy_collapse", "implement", `Discretionary open pull requests exceed the budget of ${OPEN_PR_BUDGET} per repository. Keep-red pulls do not count. Collapse before new scope.`);
  if (!input.readyParityProof) return finish("p2_ready_parity", "implement", "Owner gate is closed and discretionary entropy is inside budget. Next proof is ready-contract parity.");
  if (!input.persistenceProof) return finish("p3_persistence_proof", "implement", "Ready parity is proved. Persistence migrations are next. Do not invent the service-role key.");
  if (!input.executionProof) return finish("p4_idempotent_execution", "implement", "Persistence is proved. Idempotent execution is next. Do not open a second adapter yet.");
  if (!input.adapterSubstitutionProof) return finish("p5_adapter_substitution", "implement", "Execution proof exists. Provider substitution is the next product proof.");
  if (!input.chamberProof) return finish("p6_chamber_lifecycle", "implement", "Substitution is proved. Chamber form, work, dissolve, and audit are next.");
  if (!input.iosContractProof) return finish("p7_ios_peer_contract", "implement", "Chamber proof exists. Next is one capability model on web and iOS.");
  if (!input.deviceAcceptanceProof) return finish("p8_device_acceptance", "owner_only", "Native contract is recorded. Device fence merge is not acceptance. iPhone 16e evidence is still required.");
  return finish("p9_release_hardening", input.releaseEvidence ? "hold" : "implement", input.releaseEvidence ? "Release evidence is recorded. Hold for adversarial review. Do not open a new phase." : "Device acceptance is recorded. Release hardening is next: SideStore IPA evidence, privacy manifest, and TLS only after owner env.");
}
