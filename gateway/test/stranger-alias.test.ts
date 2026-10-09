import { describe, expect, it } from "vitest";
import { classifyAlias, summarizeAliases } from "../src/stranger-alias";

describe("stranger alias fence", () => {
  it("classifies DEPLOYMENT_NOT_FOUND as alias_absent", () => {
    const decision = classifyAlias({
      host: "quicksilverv1.vercel.app",
      status: 404,
      body: "DEPLOYMENT_NOT_FOUND",
    });
    expect(decision.classification).toBe("alias_absent");
    expect(decision.phaseAdmitted).toBe(false);
  });

  it("classifies guessed 200 HTML as stranger_occupant", () => {
    const summary = summarizeAliases([
      {
        host: "resonance.vercel.app",
        status: 200,
        body: "<!DOCTYPE html><html><title>Detail Framework</title></html>",
      },
      {
        host: "quicksilver.vercel.app",
        status: 200,
        body: "<!DOCTYPE html><html><title>Canawan</title></html>",
      },
    ]);
    expect(summary.strangerHosts).toEqual(["resonance.vercel.app", "quicksilver.vercel.app"]);
    expect(summary.phaseAdmitted).toBe(false);
  });

  it("does not admit a phase when a marker is present", () => {
    const decision = classifyAlias({
      host: "owned.example",
      status: 200,
      body: "<html>resonance-nexus</html>",
    });
    expect(decision.classification).toBe("alias_owned");
    expect(decision.phaseAdmitted).toBe(false);
  });
});
