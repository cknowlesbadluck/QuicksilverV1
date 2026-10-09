import { describe, expect, it } from "vitest";
import { assertSafeToRecord, inspectLeak } from "../src/leak-fence";

const LIVE_READY = JSON.stringify({
  status: "not_ready",
  missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"],
  timestamp: "2026-10-09T20:01:33.328Z",
});

describe("leak fence", () => {
  it("treats the live 503 body as safe to record and not admitted", () => {
    const decision = inspectLeak(LIVE_READY);
    expect(decision.leaked).toBe(false);
    expect(decision.phaseAdmitted).toBe(false);
    expect(assertSafeToRecord(LIVE_READY)).toBe(LIVE_READY);
  });

  it("refuses a jwt and does not echo it", () => {
    const token = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.signaturevalue";
    const decision = inspectLeak(`missing ${token}`);
    expect(decision.leaked).toBe(true);
    expect(decision.redacted.includes(token)).toBe(false);
    expect(() => assertSafeToRecord(`body ${token}`)).toThrow(/jwt/);
  });

  it("refuses sb_secret and a passworded postgres url", () => {
    const secret = "sb_secret_examplevalue123";
    const url = "postgresql://owner:not-a-real-password@db.example.co/postgres";
    const decision = inspectLeak(`${secret} ${url}`);
    expect(decision.kinds).toEqual(["sb_secret", "postgres_url_with_password"]);
    expect(decision.redacted.includes("not-a-real-password")).toBe(false);
  });
});
