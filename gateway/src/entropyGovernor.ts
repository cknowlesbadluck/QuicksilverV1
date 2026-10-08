/**
 * Device and portfolio fence for the Mercury gateway.
 * Simulator CI is not device acceptance. A classifier is not a deploy.
 */

export const DEVICE_GATE = "iPhone 16e hardware";
export const WITNESS_BUDGET = 2;

export type ProbeClass = "conduit_ready" | "resonance_owner_gate" | "alias_absent" | "unexpected";

export function classifyDeviceClaim(input: { simulatorCiGreen: boolean; hardwareRunRecorded: boolean }): {
  accepted: boolean;
  reason: "simulator_is_not_device_hg" | "hardware_recorded" | "not_run";
} {
  if (input.hardwareRunRecorded) return { accepted: true, reason: "hardware_recorded" };
  if (input.simulatorCiGreen) return { accepted: false, reason: "simulator_is_not_device_hg" };
  return { accepted: false, reason: "not_run" };
}

export function classifyProbe(name: "conduit_ready" | "resonance_ready" | "vercel_alias", status: number, body: Record<string, unknown>): ProbeClass {
  if (name === "vercel_alias") return status === 404 ? "alias_absent" : "unexpected";
  if (name === "conduit_ready") {
    return status === 200 && body.persistence === "postgres" ? "conduit_ready" : "unexpected";
  }
  const missing = body.missingRequired;
  return status === 503 && Array.isArray(missing) && missing[0] === "SUPABASE_SERVICE_ROLE_KEY"
    ? "resonance_owner_gate"
    : "unexpected";
}

export function admitWork(kind: "witness" | "implementation", openWitnessPulls: number): boolean {
  if (kind === "witness") return openWitnessPulls < WITNESS_BUDGET;
  return true;
}
