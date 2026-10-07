import { describe, expect, it } from "vitest";
import { claimDeviceAcceptance, healthBody } from "../src/device-acceptance";
import { handleRequest } from "../src/index";

describe("device acceptance fence", () => {
  it("never accepts a claim from the gateway", () => {
    expect(claimDeviceAcceptance()).toEqual({
      accepted: false,
      reason:
        "gateway health is liveness only; device acceptance is an iPhone 16e archive IPA and is never recorded here",
    });
  });

  it("health body names the gate and does not record acceptance", () => {
    const body = healthBody();
    expect(body.deviceAcceptance).toBe("not_recorded");
    expect(body.acceptanceGate).toBe("CHR-55");
    expect(JSON.stringify(body)).not.toMatch(/accepted.:true|iphone-16e archive passed/i);
  });
});

describe("GET /v1/health", () => {
  it("returns 200 with healthy JSON and no-store", async () => {
    const response = await handleRequest(
      new Request("https://mercury-gateway.example/v1/health", {
        method: "GET",
      }),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual(healthBody());
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

  it("health stamp is a revision name, never a secret or a device proof", async () => {
    const response = await handleRequest(
      new Request("https://mercury-gateway.example/v1/health", { method: "GET" }),
    );
    const body = await response.json();
    const serialized = JSON.stringify(body);
    expect(serialized).toContain("2026-10-07-device-fence");
    expect(serialized).toContain("not_recorded");
    expect(serialized).not.toMatch(/postgres:|eyJ|api_key|DEVICE_TOKEN/i);
  });
});
