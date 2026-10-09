/**
 * Stranger-alias fence. 17:00 EDT 2026-10-09.
 *
 * A 404 DEPLOYMENT_NOT_FOUND is alias_absent. A 200 HTML page that does not
 * carry a portfolio marker is stranger_occupant — someone else's deployment
 * on a guessed host. Ownership is not phase admission. Does not fetch,
 * invent secrets, merge pulls, or delete refs.
 */

export const STRANGER_ALIAS_REVISION = "2026-10-09-stranger-alias";

const OWNED_MARKERS = ["resonance-nexus", "service\":\"conduit", "quicksilverv1"] as const;

export type AliasClass = "alias_absent" | "stranger_occupant" | "alias_owned" | "unclassified";

export type AliasProbe = {
  host: string;
  status: number;
  body: string;
};

export type AliasDecision = {
  revision: string;
  host: string;
  classification: AliasClass;
  phaseAdmitted: false;
  owned: boolean;
};

export function classifyAlias(probe: AliasProbe): AliasDecision {
  const body = probe.body ?? "";
  const lower = body.toLowerCase();
  const absent = probe.status === 404 && body.includes("DEPLOYMENT_NOT_FOUND");
  const owned = probe.status === 200 && OWNED_MARKERS.some((marker) => lower.includes(marker));
  const html = /<!doctype|<html/i.test(body);
  let classification: AliasClass = "unclassified";
  if (absent) classification = "alias_absent";
  else if (owned) classification = "alias_owned";
  else if (probe.status === 200 && html) classification = "stranger_occupant";
  return {
    revision: STRANGER_ALIAS_REVISION,
    host: probe.host,
    classification,
    phaseAdmitted: false,
    owned: classification === "alias_owned",
  };
}

export function summarizeAliases(probes: readonly AliasProbe[]): {
  revision: string;
  strangerHosts: string[];
  absentHosts: string[];
  ownedHosts: string[];
  phaseAdmitted: false;
} {
  const decisions = probes.map(classifyAlias);
  return {
    revision: STRANGER_ALIAS_REVISION,
    strangerHosts: decisions.filter((d) => d.classification === "stranger_occupant").map((d) => d.host),
    absentHosts: decisions.filter((d) => d.classification === "alias_absent").map((d) => d.host),
    ownedHosts: decisions.filter((d) => d.classification === "alias_owned").map((d) => d.host),
    phaseAdmitted: false,
  };
}
