import { describe, expect, it } from "vitest";
import { classifyHost, decidePosture, KEEP_RED_PULLS } from "../src/host-posture";

const live = [
  { name: "conduit" as const, httpStatus: 200, body: { status: "ready", version: "0.8.0", contractRevision: "2026-10-03-ready-surface", persistence: "postgres" } },
  { name: "resonance" as const, httpStatus: 503, body: { authModeOk: true, missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"] } },
  { name: "vercel" as const, httpStatus: 404, body: {}, vercelError: "DEPLOYMENT_NOT_FOUND" },
];

describe("14:00 host posture", () => {
  it("pins live hosts and refuses a new witness", () => {
    expect(classifyHost(live[0])).toBe("ready");
    expect(classifyHost(live[1])).toBe("owner_gate");
    expect(classifyHost(live[2])).toBe("alias_absent");
    const decision = decidePosture(live, [
      { repo: "QuicksilverV1", number: 242, title: "feat: portfolio cutover lattice" },
      { repo: "Conduit", number: 155, title: "tls" },
    ]);
    expect(decision.admitNewWitness).toBe(false);
    expect(decision.keepRed).toEqual([155]);
    expect([...KEEP_RED_PULLS]).toEqual([119, 120, 155, 162]);
  });

  it("does not treat alias absence as the owner gate", () => {
    expect(classifyHost(live[2])).not.toBe("owner_gate");
  });
});
