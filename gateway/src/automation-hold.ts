/**
 * Automation hold.
 *
 * Pure. Does not call hosts, invent secrets, merge pulls, or delete branches.
 * Bolt and Dependabot pulls are real diffs, not witness stamps. They are not
 * keep-red, and they are not discretionary product scope. An unstable check
 * forbids merge. A lattice refresh must not close them as superseded.
 */

export const AUTOMATION_HOLD_REVISION = "2026-10-09-automation-hold";

export const KEEP_RED = [119, 120, 155, 162] as const;

export type PullClass = "keep_red" | "lattice" | "automation" | "product";

export type ClassifiedPull = {
  repo: string;
  number: number;
  title: string;
  author?: string;
  mergeableState?: string;
};

const KEEP = new Set<number>(KEEP_RED);

export function classifyPull(pull: Pick<ClassifiedPull, "number" | "title" | "author">): PullClass {
  if (KEEP.has(pull.number) || /keep red/i.test(pull.title)) return "keep_red";
  if (/cutover lattice/i.test(pull.title)) return "lattice";
  const author = (pull.author ?? "").toLowerCase();
  if (
    /^\s*(?:⚡\s*)?bolt\b/i.test(pull.title) ||
    /dependabot/i.test(pull.title) ||
    author.includes("dependabot") ||
    author === "jules"
  ) {
    return "automation";
  }
  return "product";
}

export function isAutomationHold(pull: Pick<ClassifiedPull, "number" | "title" | "author">): boolean {
  return classifyPull(pull) === "automation";
}

export function discretionaryCount(pulls: Array<Pick<ClassifiedPull, "number" | "title" | "author">>): number {
  return pulls.filter((pull) => classifyPull(pull) === "product" || classifyPull(pull) === "lattice").length;
}

export function assertAgentMayMerge(pull: ClassifiedPull): void {
  const klass = classifyPull(pull);
  if (klass === "keep_red") {
    throw new Error(`refusing to merge keep-red ${pull.repo}#${pull.number}`);
  }
  if (klass === "automation" && pull.mergeableState !== "clean") {
    throw new Error(`refusing to merge automation ${pull.repo}#${pull.number} while ${pull.mergeableState ?? "unknown"}`);
  }
  if (klass === "lattice") {
    throw new Error(`refusing to merge lattice ${pull.repo}#${pull.number} while the owner gate is open`);
  }
}
