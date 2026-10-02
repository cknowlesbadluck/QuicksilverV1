import { describe, expect, it } from "vitest";
import { handleRequest } from "../src/index";

describe("GET /v1/health", () => {
  it("returns 200 with healthy JSON and no-store", async () => {
    const response = handleRequest(
      new Request("https://mercury-gateway.example/v1/health", {
        method: "GET",
      }),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    await expect(response.json()).resolves.toEqual({
      ok: true,
      service: "mercury-gateway",
      route: "health",
    });
  });

  it("returns 404 for unknown paths and does not echo the path", async () => {
    const response = handleRequest(
      new Request("https://mercury-gateway.example/secret-path", {
        method: "GET",
      }),
    );
    expect(response.status).toBe(404);
    await expect(response.text()).resolves.toBe("Not Found");
  });

  it("returns 405 for non-GET on /v1/health", () => {
    const response = handleRequest(
      new Request("https://mercury-gateway.example/v1/health", {
        method: "POST",
      }),
    );
    expect(response.status).toBe(405);
  });

  it("rejects query strings so a device token cannot ride in the URL", () => {
    const response = handleRequest(
      new Request("https://mercury-gateway.example/v1/health?token=device", {
        method: "GET",
      }),
    );
    expect(response.status).toBe(400);
  });

  it("rejects fragments and userinfo", () => {
    const fragment = handleRequest(
      new Request("https://mercury-gateway.example/v1/health#token", {
        method: "GET",
      }),
    );
    expect(fragment.status).toBe(400);

    const userinfo = handleRequest(
      new Request("https://device:token@mercury-gateway.example/v1/health", {
        method: "GET",
      }),
    );
    expect(userinfo.status).toBe(400);
  });
});
