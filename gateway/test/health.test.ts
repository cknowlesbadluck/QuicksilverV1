import { describe, expect, it } from "vitest";
import { handleRequest } from "../src/index";

describe("GET /v1/health", () => {
  it("returns 200 with healthy JSON and no-store", async () => {
    const response = await handleRequest(
      new Request("https://mercury-gateway.example/v1/health", {
        method: "GET",
      }),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({
      ok: true,
      service: "mercury-gateway",
    });
  });

  it("returns 404 for unknown paths and does not echo the path", async () => {
    const response = await handleRequest(
      new Request("https://mercury-gateway.example/secret-path", {
        method: "GET",
      }),
    );
    expect(response.status).toBe(404);
    await expect(response.text()).resolves.toBe("Not Found");
  });

  it("returns 405 for non-GET on /v1/health", async () => {
    const response = await handleRequest(
      new Request("https://mercury-gateway.example/v1/health", {
        method: "POST",
      }),
    );
    expect(response.status).toBe(405);
  });

  it("rejects query strings so a device token cannot ride in the URL", async () => {
    const response = await handleRequest(
      new Request("https://mercury-gateway.example/v1/health?token=device", {
        method: "GET",
      }),
    );
    expect(response.status).toBe(400);
  });

  it("rejects fragments", async () => {
    const fragment = await handleRequest(
      new Request("https://mercury-gateway.example/v1/health#token", {
        method: "GET",
      }),
    );
    expect(fragment.status).toBe(400);
  });

  // Fetch Request forbids credentialed URLs (throws before the handler runs).
  // Exercise the userinfo guard with a minimal { url, method } stand-in.
  it("rejects userinfo", async () => {
    const userinfo = await handleRequest({
      url: "https://device:token@mercury-gateway.example/v1/health",
      method: "GET",
    } as Request);
    expect(userinfo.status).toBe(400);
  });
});
