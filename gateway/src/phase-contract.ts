/**
 * Portfolio phase contract.
 * Pure. Does not call hosts, invent secrets, merge pulls, or delete branches.
 * A stamp is not a phase advance. Owner gates stay owner gates.
 * Gateway health 200 is not iPhone 16e acceptance.
 */

export const PHASE_CONTRACT_REVISION = "2026-10-09-phase-contract";

export type PhaseOwner = "agent" | "owner";

export type Phase = {
  id: number;
  name: string;
  owner: PhaseOwner;
  exit: string;
};

export const PHASES: readonly Phase[] = [
  { id: 1, name: "Surface truth", owner: "agent", exit: "Conduit /health and /ready 200 share contractRevision and persistence postgres; Resonance /api/ready names the exact missing key and omits ownerActionRequired; Vercel alias 404 is alias_absent." },
  { id: 2, name: "Owner persistence gate", owner: "owner", exit: "Resonance Supabase unpaused and SUPABASE_SERVICE_ROLE_KEY set on Netlify resonancenexus only. Agent must not invent the secret." },
  { id: 3, name: "Entropy collapse", owner: "agent", exit: "Lattice PRs merged or closed only after phase 2; keep-red and automation-hold pulls remain open; no new witness PR." },
  { id: 4, name: "Conduit durability", owner: "owner", exit: "Render TLS env set, then #155 and #162 may be reviewed. #119 and #120 stay draft until ordered migrations and SSE admission are green." },
  { id: 5, name: "Capability model", owner: "agent", exit: "Resonance #155 retires the client-only capability shape on main without a second model." },
  { id: 6, name: "Device acceptance", owner: "owner", exit: "iPhone 16e device HG recorded. Simulator CI is not CHR-55. Gateway health 200 is not acceptance." },
  { id: 7, name: "Gateway cutover", owner: "owner", exit: "mercury-gateway deploy is owner-only and health stamp matches the landed contract. Not device proof." },
  { id: 8, name: "First real adapter", owner: "agent", exit: "GitHub adapter configured is no longer advisory-only; one vertical slice resolves and executes with idempotency." },
  { id: 9, name: "Chamber evidence", owner: "agent", exit: "A chamber forms, works, dissolves, and leaves an audit row. Conduit stays project-agnostic." },
  { id: 10, name: "Release cut", owner: "owner", exit: "release/0.8.0 reconciled or explicitly abandoned; tag only after live /ready matches the tagged revision. Post-deploy probe is the proof." }
];

export type Probe = {
  resonanceStatus: number;
  resonanceMissing?: string[];
  vercelStatus: number;
  supabasePaused?: boolean;
  deviceHgRecorded?: boolean;
};

export type Classification = {
  revision: string;
  phaseCount: number;
  currentPhase: number;
  ownerBlocked: boolean;
  deviceUnrecorded: boolean;
  aliasAbsent: boolean;
  stampIsNotAdvance: true;
  secretsInvented: false;
};

export function classifyProbe(probe: Probe): Classification {
  const missing = probe.resonanceMissing ?? [];
  const ownerBlocked = probe.resonanceStatus !== 200 || missing.includes("SUPABASE_SERVICE_ROLE_KEY") || probe.supabasePaused === true;
  const deviceUnrecorded = probe.deviceHgRecorded !== true;
  const aliasAbsent = probe.vercelStatus === 404;
  return {
    revision: PHASE_CONTRACT_REVISION,
    phaseCount: PHASES.length,
    currentPhase: ownerBlocked ? 2 : deviceUnrecorded ? 6 : 8,
    ownerBlocked,
    deviceUnrecorded,
    aliasAbsent,
    stampIsNotAdvance: true,
    secretsInvented: false
  };
}

export function assertNoSecretInvention(body: unknown): void {
  const text = JSON.stringify(body);
  if (/service_role|eyJ/.test(text)) throw new Error("refusing to carry a secret");
}

export function assertStampDoesNotAdvance(before: Classification, after: Classification): void {
  if (before.ownerBlocked && !after.ownerBlocked) {
    throw new Error("a stamp cannot clear the owner gate");
  }
  if (before.deviceUnrecorded && !after.deviceUnrecorded && after.stampIsNotAdvance) {
    throw new Error("a stamp cannot record device acceptance");
  }
}
