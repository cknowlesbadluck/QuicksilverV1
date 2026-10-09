/**
 * Audit hardening. 14:00 EDT 2026-10-09.
 *
 * Probe-driven. A revision stamp is not a phase advance.
 * Callers may delete only names returned in pruneThisPass.
 * Hold refs and already-pruned fence names are refused.
 * Does not call hosts, invent secrets, merge pulls, or delete refs.
 */

import { evaluateSpine, PRUNED_FENCE_BRANCHES, type SpineProbe } from "./phase-spine";

export const AUDIT_HARDENING_REVISION = "2026-10-09-audit-hardening";

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

const AUTOMATION_HOLDS = new Set([188, 209]);
const KEEP_RED = new Set([119, 120, 155, 162]);
const DISCRETIONARY_CAP = 2;

export type LiveRef = {
  repo: string;
  name: string;
  openPull: number | null;
};

export type AuditDecision = {
  revision: string;
  priorRevision: string;
  currentPhase: number;
  stampIsNotAdvance: true;
  entropySatisfied: boolean;
  discretionaryByRepo: Record<string, number>;
  pruneThisPass: string[];
  holdNotDelete: string[];
  reopenRefusal: string | null;
  pruneRefusal: string | null;
  ownerActions: string[];
  secretInvented: false;
  notMerged: number[];
};

export function classifyInventory(refs: readonly LiveRef[]): { prune: string[]; hold: string[] } {
  const prune: string[] = [];
  const hold: string[] = [];
  for (const ref of refs) {
    if (ref.name === "main") continue;
    const key = `${ref.repo}:${ref.name}`;
    const held = (HOLD_NOT_DELETE as readonly string[]).includes(ref.name) || ref.openPull !== null;
    if (held) hold.push(key);
    else prune.push(key);
  }
  return { prune, hold };
}

export function discretionaryCounts(refs: readonly LiveRef[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const ref of refs) {
    if (ref.openPull === null) continue;
    if (AUTOMATION_HOLDS.has(ref.openPull) || KEEP_RED.has(ref.openPull)) continue;
    counts[ref.repo] = (counts[ref.repo] ?? 0) + 1;
  }
  return counts;
}

export function evaluateAudit(
  probe: SpineProbe,
  refs: readonly LiveRef[],
  attempted: string | null = null,
): AuditDecision {
  const spine = evaluateSpine(probe, attempted);
  const inventory = classifyInventory(refs);
  const discretionaryByRepo = discretionaryCounts(refs);
  const entropySatisfied = inventory.prune.length === 0
    && Object.values(discretionaryByRepo).every((count) => count <= DISCRETIONARY_CAP);
  const pruneRefusal = attempted !== null && (HOLD_NOT_DELETE as readonly string[]).includes(attempted)
    ? `refusing to prune hold ref ${attempted}`
    : null;
  if (pruneRefusal) {
    throw new Error(pruneRefusal);
  }
  return {
    revision: AUDIT_HARDENING_REVISION,
    priorRevision: spine.revision,
    currentPhase: spine.currentPhase,
    stampIsNotAdvance: true,
    entropySatisfied,
    discretionaryByRepo,
    pruneThisPass: inventory.prune,
    holdNotDelete: [...HOLD_NOT_DELETE],
    reopenRefusal: spine.reopenRefusal,
    pruneRefusal,
    ownerActions: [
      "Unpause Resonance Supabase, then set SUPABASE_SERVICE_ROLE_KEY on Netlify resonancenexus only.",
      "Record device HG on iPhone 16e. A merged device-fence pull is not this exit.",
    ],
    secretInvented: false,
    notMerged: [...NOT_MERGE],
  };
}

export function assertStampDoesNotClearOwner(beforePhase: number, afterPhase: number): void {
  if (beforePhase === 0 && afterPhase !== 0) {
    throw new Error("a stamp cannot clear the owner gate");
  }
}

export { PRUNED_FENCE_BRANCHES };
