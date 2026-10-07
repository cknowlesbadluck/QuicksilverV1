/**
 * Device acceptance is not a gateway property.
 * /v1/health is process liveness. CHR-55 is an iPhone 16e archive IPA.
 * This module cannot be satisfied by a unit test, a simulator log, or a health 200.
 */

export const DEVICE_ACCEPTANCE = "not_recorded" as const;
export const ACCEPTANCE_GATE = "CHR-55";
export const HEALTH_CONTRACT_REVISION = "2026-10-07-device-fence";

export type DeviceAcceptanceBody = {
  ok: true;
  service: "mercury-gateway";
  contractRevision: typeof HEALTH_CONTRACT_REVISION;
  deviceAcceptance: typeof DEVICE_ACCEPTANCE;
  acceptanceGate: typeof ACCEPTANCE_GATE;
};

export function healthBody(): DeviceAcceptanceBody {
  return {
    ok: true,
    service: "mercury-gateway",
    contractRevision: HEALTH_CONTRACT_REVISION,
    deviceAcceptance: DEVICE_ACCEPTANCE,
    acceptanceGate: ACCEPTANCE_GATE,
  };
}

export type DeviceClaim = {
  accepted: false;
  reason: string;
};

/** Always rejects. The gateway has no device, no IPA, and no acceptance record. */
export function claimDeviceAcceptance(): DeviceClaim {
  return {
    accepted: false,
    reason:
      "gateway health is liveness only; device acceptance is an iPhone 16e archive IPA and is never recorded here",
  };
}
