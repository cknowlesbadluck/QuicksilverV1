/**
 * Collapse receipt. Executable disposition for the 23:00 EDT portfolio pass.
 *
 * Pure. Does not call hosts, invent secrets, merge pull requests, or archive
 * repositories. A receipt names the pulls to close and the heads to delete.
 * Keep-red numbers and the canonical lattice head are structurally excluded.
 */

import { KEEP_RED, decidePhaseLock, type OpenPull } from "./phase-lock.js";

export const COLLAPSE_REVISION = "2026-10-08-2300-collapse";

export const CANONICAL_HEAD = "feat/cutover-lattice-1000";

export type CollapsePull = OpenPull & { headRef: string };

export type CollapseReceipt = {
  revision: string;
  openNewWitness: false;
  inventSecret: false;
  mergeKeepRed: false;
  close: Array<{ repo: string; number: number; headRef: string }>;
  deleteHeads: Array<{ repo: string; headRef: string }>;
  hold: Array<{ repo: string; number: number; headRef: string }>;
  forbidden: string[];
};

const KEEP = new Set<number>(KEEP_RED);

export function buildCollapseReceipt(pulls: CollapsePull[], latticeOpen: boolean): CollapseReceipt {
  const decision = decidePhaseLock({ latticeOpen, pulls });
  const byNumber = new Map(pulls.map((pull) => [pull.number, pull]));
  const close = decision.closeNumbers
    .filter((number) => !KEEP.has(number))
    .map((number) => {
      const pull = byNumber.get(number);
      if (!pull || pull.headRef === CANONICAL_HEAD) {
        throw new Error(`refusing to close ${number}: missing pull or canonical head`);
      }
      return { repo: pull.repo, number, headRef: pull.headRef };
    });
  const deleteHeads = close.map((row) => ({ repo: row.repo, headRef: row.headRef }));
  const hold = decision.holdNumbers.map((number) => {
    const pull = byNumber.get(number);
    if (!pull) throw new Error(`missing hold pull ${number}`);
    return { repo: pull.repo, number, headRef: pull.headRef };
  });
  return {
    revision: COLLAPSE_REVISION,
    openNewWitness: false,
    inventSecret: false,
    mergeKeepRed: false,
    close,
    deleteHeads,
    hold,
    forbidden: [
      "Do not invent SUPABASE_SERVICE_ROLE_KEY.",
      "Do not merge Conduit #119 #120 #155 #162.",
      "Do not open a new witness family while feat/cutover-lattice-1000 is open.",
      "Do not treat resonancenexus.vercel.app 404 DEPLOYMENT_NOT_FOUND as an owner gate.",
      "Do not treat simulator CI as iPhone 16e device acceptance.",
      "Legacy cknowlesbadluck/Quicksilver is already archived. Do not retry archive.",
    ],
  };
}
