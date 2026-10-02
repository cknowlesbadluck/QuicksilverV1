import { describe, expect, it } from "vitest";
import { handleRequest } from "../src/index";

describe("GET /v1/health", () => {
  it("returns 200 with healthy JSON", async () => {
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
    });
  });

  it("returns 404 for unknown paths", () => {
    const response = handleRequest(
      new Request("https://mercury-gateway.example/", { method: "GET" }),
    );
    expect(response.status).toBe(404);
  });

  it("returns 404 for non-GET on /v1/health", () => {
    const response = handleRequest(
      new Request("https://mercury-gateway.example/v1/health", {
        method: "POST",
      }),
    );
    expect(response.status).toBe(404);
  });
});
