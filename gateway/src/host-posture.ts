/**
 * Host posture pin for the 14:00 EDT 2026-10-08 portfolio probe.
 * Pure classifier. Does not call hosts, invent secrets, or deploy the gateway.
 */

export const POSTURE_REVISION = "2026-10-08-1400-host-posture";
export const CONDUIT_CONTRACT = "2026-10-03-ready-surface";
export const OWNER_SECRET = "SUPABASE_SERVICE_ROLE_KEY";
export const KEEP_RED_PULLS = [119, 120, 155, 162] as const;

export type HostName = "conduit" | "resonance" | "vercel";
export type HostClass = "ready" | "owner_gate" | "alias_absent" | "drift";
export type ObservedHost = { name: HostName; httpStatus: number; body: Record<string, unknown>; vercelError?: string };
export type OpenPull = { repo: string; number: number; title: string };
export type HostPosture = { revision: string; classes: Record<HostName, HostClass>; pinHolds: boolean; admitNewWitness: boolean; keepRed: number[]; reason: string };

const OMITTED = ["ownerActionRequired", "contractRevision"] as const;

export function classifyHost(host: ObservedHost): HostClass {
  if (host.name === "vercel") return host.httpStatus === 404 && host.vercelError === "DEPLOYMENT_NOT_FOUND" ? "alias_absent" : "drift";
  if (host.name === "conduit") {
    return host.httpStatus === 200 && host.body.status === "ready" && host.body.version === "0.8.0" && host.body.contractRevision === CONDUIT_CONTRACT && host.body.persistence === "postgres" ? "ready" : "drift";
  }
  const missing = host.body.missingRequired;
  const exactMissing = Array.isArray(missing) && missing.length === 1 && missing[0] === OWNER_SECRET;
  const omitted = OMITTED.every((key) => !Object.prototype.hasOwnProperty.call(host.body, key));
  return host.httpStatus === 503 && exactMissing && omitted && host.body.authModeOk === true ? "owner_gate" : "drift";
}

export function decidePosture(hosts: ObservedHost[], openPulls: OpenPull[]): HostPosture {
  const classes = {
    conduit: classifyHost(hosts.find((host) => host.name === "conduit") ?? { name: "conduit", httpStatus: 0, body: {} }),
    resonance: classifyHost(hosts.find((host) => host.name === "resonance") ?? { name: "resonance", httpStatus: 0, body: {} }),
    vercel: classifyHost(hosts.find((host) => host.name === "vercel") ?? { name: "vercel", httpStatus: 0, body: {} }),
  };
  const pinHolds = classes.conduit === "ready" && classes.resonance === "owner_gate" && classes.vercel === "alias_absent";
  const latticeOpen = openPulls.some((pull) => pull.title.toLowerCase().includes("cutover lattice"));
  return {
    revision: POSTURE_REVISION,
    classes,
    pinHolds,
    admitNewWitness: !(pinHolds && latticeOpen),
    keepRed: openPulls.filter((pull) => (KEEP_RED_PULLS as readonly number[]).includes(pull.number)).map((pull) => pull.number),
    reason: pinHolds && latticeOpen ? "Live pin holds and a cutover lattice pull request is open. Refuse a new witness." : pinHolds ? "Live pin holds. Owner gate remains owner-only." : "Live pin drifted.",
  };
}
