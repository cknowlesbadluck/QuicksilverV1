/**
 * Phase lock. Pure disposition for the 23:00 EDT portfolio pass.
 *
 * Does not call hosts, invent secrets, merge pull requests, or archive repos.
 * Callers pass already-observed facts. The lock refuses a new witness family
 * while a cutover-lattice pull request is open, and it never emits merge for
 * keep-red numbers.
 */

export const PHASE_LOCK_REVISION = "2026-10-08-2300-collapse";

export const KEEP_RED = [119, 120, 155, 162] as const;

export const CANONICAL_FAMILY = "cutover-lattice";

export const SUPERSEDED_FAMILIES = [
  "phase-clock",
  "degrade-planner",
  "work-admission",
  "entropy-governor",
  "public-ready-pin",
] as const;

export type Disposition = "keep_red" | "canonical" | "close_superseded" | "hold";

export type OpenPull = {
  repo: string;
  number: number;
  title: string;
};

export type PhaseLockInput = {
  latticeOpen: boolean;
  pulls: OpenPull[];
};

export type PhaseLockDecision = {
  revision: string;
  openNewWitness: false;
  dispositions: Array<OpenPull & { disposition: Disposition; reason: string }>;
  closeNumbers: number[];
  holdNumbers: number[];
};

function familyOf(title: string): string {
  const normalized = title.toLowerCase();
  if (normalized.includes("cutover lattice")) return CANONICAL_FAMILY;
  if (normalized.includes("entropy governor")) return "entropy-governor";
  if (normalized.includes("degrade planner")) return "degrade-planner";
  if (normalized.includes("work admission")) return "work-admission";
  if (normalized.includes("phase clock")) return "phase-clock";
  if (normalized.includes("ready body") || normalized.includes("ready pin")) return "public-ready-pin";
  if (normalized.includes("device acceptance")) return "device-acceptance";
  if (normalized.includes("dependabot") || normalized.includes("actions/checkout")) return "dependency";
  return "other";
}

export function disposePull(pull: OpenPull, latticeOpen: boolean): Disposition {
  if ((KEEP_RED as readonly number[]).includes(pull.number)) return "keep_red";
  const family = familyOf(pull.title);
  if (family === CANONICAL_FAMILY) return "canonical";
  if (latticeOpen && (SUPERSEDED_FAMILIES as readonly string[]).includes(family)) return "close_superseded";
  return "hold";
}

export function decidePhaseLock(input: PhaseLockInput): PhaseLockDecision {
  const dispositions = input.pulls.map((pull) => {
    const disposition = disposePull(pull, input.latticeOpen);
    const reason =
      disposition === "keep_red"
        ? "Keep-red. Do not merge until the owner environment is set."
        : disposition === "canonical"
          ? "Current lattice witness. Refresh in place. Do not open another family."
          : disposition === "close_superseded"
            ? "Superseded by the open cutover lattice. Close the pull request and delete the head branch."
            : "Hold. Not a superseded witness family and not keep-red.";
    return { ...pull, disposition, reason };
  });
  return {
    revision: PHASE_LOCK_REVISION,
    openNewWitness: false,
    dispositions,
    closeNumbers: dispositions.filter((row) => row.disposition === "close_superseded").map((row) => row.number),
    holdNumbers: dispositions.filter((row) => row.disposition === "hold").map((row) => row.number),
  };
}
