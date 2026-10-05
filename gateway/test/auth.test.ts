import { describe, expect, it } from "vitest";
import { authenticate, bearerToken, constantTimeEqual } from "../src/auth";

const TOKEN = "test-device-token-not-a-secret";

function withAuth(value?: string): Pick<Request, "headers"> {
  const headers = new Headers();
  if (value !== undefined) headers.set("authorization", value);
  return { headers };
}

describe("bearerToken", () => {
  it("parses a Bearer header (scheme is case-insensitive)", () => {
    expect(bearerToken("Bearer abc")).toBe("abc");
    expect(bearerToken("bearer abc")).toBe("abc");
  });

  it("rejects missing, empty, and non-Bearer headers", () => {
    expect(bearerToken(null)).toBeNull();
    expect(bearerToken("")).toBeNull();
    expect(bearerToken("Bearer")).toBeNull();
    expect(bearerToken("Bearer ")).toBeNull();
    expect(bearerToken("Basic abc")).toBeNull();
    expect(bearerToken("Bearer a b")).toBeNull();
  });
});

describe("authenticate", () => {
  it("rejects a missing token", async () => {
    await expect(authenticate(withAuth(), TOKEN)).resolves.toEqual({ ok: false });
  });

  it("rejects a wrong token, including prefixes and extensions of the right one", async () => {
    for (const wrong of ["nope", TOKEN.slice(0, -1), `${TOKEN}x`, TOKEN.toUpperCase()]) {
      await expect(authenticate(withAuth(`Bearer ${wrong}`), TOKEN)).resolves.toEqual({
        ok: false,
      });
    }
  });

  it("accepts the right token and keys limits by a digest, not the raw token", async () => {
    const result = await authenticate(withAuth(`Bearer ${TOKEN}`), TOKEN);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.tokenKey).toMatch(/^[0-9a-f]{64}$/);
    expect(result.tokenKey).not.toContain(TOKEN);
  });

  it("fails closed when DEVICE_TOKEN is unset or empty", async () => {
    await expect(authenticate(withAuth(`Bearer ${TOKEN}`), undefined)).resolves.toEqual({
      ok: false,
    });
    await expect(authenticate(withAuth("Bearer "), "")).resolves.toEqual({ ok: false });
  });
});

describe("constantTimeEqual", () => {
  it("returns true only for identical bytes", () => {
    expect(constantTimeEqual([1, 2, 3], [1, 2, 3])).toBe(true);
    expect(constantTimeEqual([9, 2, 3], [1, 2, 3])).toBe(false);
    expect(constantTimeEqual([1, 2, 9], [1, 2, 3])).toBe(false);
    expect(constantTimeEqual([1, 2], [1, 2, 3])).toBe(false);
    expect(constantTimeEqual([], [])).toBe(true);
  });

  // Counts element reads: a short-circuiting compare would read fewer bytes when the
  // first byte differs than when only the last byte differs.
  function reads(a: number[], b: number[]): number {
    let count = 0;
    const counted = (arr: number[]) =>
      new Proxy(arr, {
        get(target, prop, receiver) {
          if (typeof prop === "string" && /^\d+$/.test(prop)) count += 1;
          return Reflect.get(target, prop, receiver);
        },
      });
    constantTimeEqual(counted(a), counted(b));
    return count;
  }

  it("reads every byte no matter where the first mismatch is", () => {
    const base = Array.from({ length: 32 }, (_, i) => i);
    const firstDiffers = [255, ...base.slice(1)];
    const lastDiffers = [...base.slice(0, 31), 255];
    expect(reads(firstDiffers, base)).toBe(64);
    expect(reads(lastDiffers, base)).toBe(64);
    expect(reads([...base], base)).toBe(64);
  });
});
