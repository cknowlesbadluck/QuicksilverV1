import { describe, expect, it } from "vitest";
import { planDegrade } from "../src/degrade";

describe("planDegrade", () => {
  it("treats a 503 with a setting name as an owner gate and does not echo values", () => {
    const plan = planDegrade({
      status: 503,
      missingRequired: ["SUPABASE_SERVICE_ROLE_KEY", "postgres://user:secret@db/app"],
      bodyText: "eyJhbGciOiJIUzI1NiJ9.payload",
    });
    expect(plan).toEqual({
      host: "owner_gate",
      action: "ask_owner",
      retryable: false,
      missingNames: ["SUPABASE_SERVICE_ROLE_KEY"],
    });
    expect(JSON.stringify(plan)).not.toMatch(/postgres:|eyJ|secret/i);
  });

  it("treats DEPLOYMENT_NOT_FOUND as an absent alias, not an owner gate", () => {
    const plan = planDegrade({
      status: 404,
      bodyText: "DEPLOYMENT_NOT_FOUND",
      missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
    });
    expect(plan.action).toBe("ignore_alias");
    expect(plan.host).toBe("alias_absent");
    expect(plan.missingNames).toEqual([]);
  });

  it("sends budget exhaustion on-device and rate limits to backoff", () => {
    expect(planDegrade({ status: 200, code: "budget_exhausted" }).action).toBe("stay_local");
    expect(planDegrade({ status: 429 }).retryable).toBe(true);
    expect(planDegrade({ status: 429 }).action).toBe("backoff");
  });

  it("reauths on 401 and proceeds only on a clean 200", () => {
    expect(planDegrade({ status: 401 }).action).toBe("reauth");
    expect(planDegrade({ status: 200, code: "ready" }).action).toBe("proceed");
    expect(planDegrade({ status: 500, bodyText: "boom" }).action).toBe("stay_local");
  });
});
