/**
 * Degrade planner.
 *
 * Maps a host probe or gateway error into one on-device action.
 * Fail closed. Names of missing settings may be classified; values never are.
 * This module does not fetch, store, or invent credentials.
 */

export type HostClass =
  | "ready"
  | "owner_gate"
  | "alias_absent"
  | "auth_required"
  | "rate_limited"
  | "budget_exhausted"
  | "unknown";

export type DegradeAction =
  | "proceed"
  | "ask_owner"
  | "ignore_alias"
  | "reauth"
  | "backoff"
  | "stay_local";

export interface Probe {
  status: number;
  code?: string;
  missingRequired?: readonly string[];
  bodyText?: string;
}

export interface DegradePlan {
  host: HostClass;
  action: DegradeAction;
  retryable: boolean;
  missingNames: string[];
}

const NAME = /^[A-Z][A-Z0-9_]{2,64}$/;

export function planDegrade(probe: Probe): DegradePlan {
  const missingNames = (probe.missingRequired ?? []).filter(
    (name) => typeof name === "string" && NAME.test(name),
  );
  const text = probe.bodyText ?? "";
  const code = probe.code ?? "";

  if (code === "budget_exhausted" || code === "budgetExhausted") {
    return { host: "budget_exhausted", action: "stay_local", retryable: false, missingNames };
  }
  if (code === "rate_limited" || code === "rateLimited" || probe.status === 429) {
    return { host: "rate_limited", action: "backoff", retryable: true, missingNames };
  }
  if (code === "unauthorized" || probe.status === 401 || probe.status === 403) {
    return { host: "auth_required", action: "reauth", retryable: false, missingNames };
  }
  if (probe.status === 404 && text.includes("DEPLOYMENT_NOT_FOUND")) {
    return { host: "alias_absent", action: "ignore_alias", retryable: false, missingNames: [] };
  }
  if (probe.status === 503 && missingNames.length > 0) {
    return { host: "owner_gate", action: "ask_owner", retryable: false, missingNames };
  }
  if (probe.status === 200 && (code === "" || code === "ok" || code === "ready")) {
    return { host: "ready", action: "proceed", retryable: false, missingNames: [] };
  }
  return { host: "unknown", action: "stay_local", retryable: false, missingNames: [] };
}
