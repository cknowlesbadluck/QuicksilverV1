/**
 * Hygiene prune. Pure. Does not call hosts, invent secrets, merge pulls,
 * delete branches, or archive repositories.
 *
 * A diverged release branch is not an orphan. An archived repository is
 * already pruned. Keep-red pulls are an owner hold. A paused Supabase
 * project cannot be turned into persistence proof by setting a key.
 */

export const HYGIENE_REVISION = "2026-10-09-automation-hold";

import { classifyPull } from "./automation-hold";

export const KEEP_RED = [119, 120, 155, 162] as const;

export type SupabaseProject = {
  name: string;
  status: "ACTIVE" | "INACTIVE" | "UNKNOWN";
};

export type BranchFact = {
  repo: string;
  name: string;
  diverged?: boolean;
  archivedRepo?: boolean;
};

export type PullFact = {
  repo: string;
  number: number;
  title: string;
};

export type HygieneInput = {
  projects: SupabaseProject[];
  branches: BranchFact[];
  pulls: PullFact[];
  latticeFamilyOpen: boolean;
  missingRequired: string[];
  legacyArchived: boolean;
  mcpArchived: boolean;
};

export type PruneDisposition =
  | "already_pruned"
  | "keep_unmerged"
  | "hold_not_delete"
  | "hold_until_ci"
  | "automation_hold"
  | "refresh_in_place"
  | "owner_unpause";

export type HygieneDecision = {
  revision: string;
  openNewWitness: false;
  deleteBranches: [];
  closePulls: [];
  mergePulls: [];
  persistenceProof: false;
  singleLegalAction: "owner_unpause_then_set_key";
  dispositions: Array<{ target: string; disposition: PruneDisposition; reason: string }>;
};

function isKeepRed(number: number): boolean {
  return (KEEP_RED as readonly number[]).includes(number);
}

export function persistenceBlocked(projects: SupabaseProject[]): boolean {
  return projects.some((project) => project.status !== "ACTIVE");
}

export function decideHygiene(input: HygieneInput): HygieneDecision {
  if (!input.latticeFamilyOpen) {
    throw new Error("refusing a new witness family; refresh the open cutover lattice");
  }
  if (input.missingRequired.includes("SUPABASE_SERVICE_ROLE_KEY") === false) {
    throw new Error("refusing to drop the owner key from the live ready body");
  }
  if (!persistenceBlocked(input.projects)) {
    throw new Error("refusing persistence proof while this pass observed no inactive project");
  }

  const dispositions: HygieneDecision["dispositions"] = [];

  for (const project of input.projects) {
    dispositions.push({
      target: `supabase:${project.name}`,
      disposition: "owner_unpause",
      reason: `${project.status} is not persistence. Unpause before setting any key.`,
    });
  }

  for (const branch of input.branches) {
    if (branch.archivedRepo) {
      dispositions.push({
        target: `${branch.repo}#${branch.name}`,
        disposition: "already_pruned",
        reason: "Repository is archived. Do not retry archive.",
      });
      continue;
    }
    if (branch.diverged) {
      dispositions.push({
        target: `${branch.repo}#${branch.name}`,
        disposition: "hold_not_delete",
        reason: "Diverged from main. Deleting it is not hygiene.",
      });
    }
  }

  for (const pull of input.pulls) {
    if (isKeepRed(pull.number)) {
      dispositions.push({
        target: `${pull.repo}#${pull.number}`,
        disposition: "keep_unmerged",
        reason: "Keep-red until the owner sets Render Postgres TLS env.",
      });
      continue;
    }
    const klass = classifyPull(pull);
    if (klass === "lattice") {
      dispositions.push({
        target: `${pull.repo}#${pull.number}`,
        disposition: "refresh_in_place",
        reason: "Canonical lattice. Do not open another witness family.",
      });
      continue;
    }
    if (klass === "automation") {
      dispositions.push({
        target: `${pull.repo}#${pull.number}`,
        disposition: "automation_hold",
        reason: "Bolt or Dependabot diff. Do not merge while unstable. Do not close as a superseded witness.",
      });
      continue;
    }
    dispositions.push({
      target: `${pull.repo}#${pull.number}`,
      disposition: "hold_until_ci",
      reason: "Not keep-red and not a superseded witness. Do not close without a green required check.",
    });
  }

  if (input.legacyArchived) {
    dispositions.push({
      target: "cknowlesbadluck/Quicksilver",
      disposition: "already_pruned",
      reason: "Archived. Do not retry archive.",
    });
  }
  if (input.mcpArchived) {
    dispositions.push({
      target: "cknowlesbadluck/mcp",
      disposition: "already_pruned",
      reason: "Archived. Do not revive the old MCP repo.",
    });
  }

  return {
    revision: HYGIENE_REVISION,
    openNewWitness: false,
    deleteBranches: [],
    closePulls: [],
    mergePulls: [],
    persistenceProof: false,
    singleLegalAction: "owner_unpause_then_set_key",
    dispositions,
  };
}
