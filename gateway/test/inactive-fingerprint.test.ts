import { describe, expect, it } from "vitest";
import { classifyFingerprint, classifyPass, classifyPersistence } from "../src/inactive-fingerprint";

describe("inactive fingerprint fence", () => {
  it("lets a known stranger analytics id beat a spoofed marker", () => {
    const decision = classifyFingerprint({
      host: "quicksilver.vercel.app",
      status: 200,
      body: "<!DOCTYPE html><html><title>Canawan</title>quicksilverv1 UA-160004791-1</html>",
    });
    expect(decision.classification).toBe("stranger_occupant");
    expect(decision.spoofedMarker).toBe(true);
    expect(decision.phaseAdmitted).toBe(false);
  });

  it("classifies Detail Framework as stranger_occupant", () => {
    const decision = classifyFingerprint({
      host: "resonance.vercel.app",
      status: 200,
      body: "<!DOCTYPE html><html><title>Detail Framework</title>data-cruncher</html>",
    });
    expect(decision.classification).toBe("stranger_occupant");
    expect(decision.phaseAdmitted).toBe(false);
  });

  it("does not treat INACTIVE projects as persistence", () => {
    const persistence = classifyPersistence([
      { name: "Resonance", status: "INACTIVE" },
      { name: "Quicksilver: Mercurial intelligence", status: "INACTIVE" },
      { name: "WhereamI?", status: "INACTIVE" },
    ]);
    expect(persistence.persistenceProof).toBe(false);
    expect(persistence.inactiveNames).toHaveLength(3);
  });

  it("keeps the owner gate at phase 0", () => {
    const pass = classifyPass({
      missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
      projects: [{ status: "INACTIVE" }],
      deviceRecorded: false,
    });
    expect(pass.classification).toBe("owner_blocked");
    expect(pass.highestAdmittedPhase).toBe(0);
    expect(pass.phaseAdmitted).toBe(false);
  });
});
