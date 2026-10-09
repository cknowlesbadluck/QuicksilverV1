/**
 * Landed fence.
 *
 * A squash-merge is not acceptance. The device fence can be on main and still
 * be unverified until the owner records an iPhone 16e human gate.
 * Pure. Does not call hosts, invent secrets, or merge pull requests.
 */

export const LANDED_FENCE_REVISION = "2026-10-09-landed-fence";

export type LandedClaim = "device_fence" | "other";

export type LandedPull = {
  repo: string;
  number: number;
  sha: string;
  claim: LandedClaim;
  deviceRecorded: boolean;
};

export type LandedVerdict = "landed_unverified" | "landed_accepted";

export const DEVICE_FENCE_LANDED: LandedPull = {
  repo: "QuicksilverV1",
  number: 241,
  sha: "83f13504cda74e4150baab3be3de70f2251ab441",
  claim: "device_fence",
  deviceRecorded: false,
};

export function classifyLanded(pull: LandedPull): LandedVerdict {
  if (pull.claim === "device_fence" && !pull.deviceRecorded) return "landed_unverified";
  return "landed_accepted";
}

export function holdContradictions(openNumbers: readonly number[], landed: readonly LandedPull[]): number[] {
  const landedNumbers = new Set(landed.map((pull) => pull.number));
  return openNumbers.filter((number) => landedNumbers.has(number));
}
