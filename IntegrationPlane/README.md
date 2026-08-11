# Quicksilver Integration Plane

The Integration Plane is the boundary between Quicksilver and the external AI/development ecosystem.

## Goals

- One orchestration surface for AI providers, APIs, development platforms, project management, design, deployment, and automation.
- MCP-first so one governed endpoint can be used by ChatGPT, Claude, Codex, Cursor, Gemini, and other MCP clients.
- Provider-neutral routing with primary, secondary, and fallback paths.
- Credential-safe design: secrets are never embedded in Swift, source files, prompts, manifests, or tool payloads.
- Human approval gates for repository writes, pull requests, files, deployments, and other consequential operations.
- Swift-native client in `Nexus/Integration/` so the iOS application can discover tools and invoke the same plane.

## Current connector registry

AI: OpenAI, Anthropic, Google AI, xAI.

Development: GitHub, Linear, Google.

Build/design/deployment: Cursor, Replit, Figma, Vercel, Netlify, Supabase, Convex, Lovable, AppDeploy, n8n.

The registry is intentionally extensible. A connector is a capability provider, not a hard-coded dependency of Quicksilver.

## Noodle Seed

`server.ts` is authored for Noodle Seed's declarative TypeScript runtime. Noodle Seed turns the source into a governed MCP endpoint with identity, credential management, policy, auditability, rate limits, TLS, and operational controls.

The project should be initialized and validated with the Noodle Seed CLI before deployment. Generated Noodle artifacts are intentionally not hand-authored in this repository.

## Swift integration

`Nexus/Integration/IntegrationPlaneClient.swift` provides a small actor-isolated MCP JSON-RPC client using `URLSession` and async/await. It supports:

1. MCP initialization.
2. Tool discovery.
3. Tool invocation.
4. Session ID propagation.
5. JSON and SSE-style responses.
6. Credential-safe error handling.

The client is transport-only. Provider credentials remain outside the iOS binary.

## Routing model

Quicksilver should generally resolve a request as:

`intent -> capability -> preferred provider -> secondary provider -> fallback -> approval -> execution -> result`

This prevents the application from becoming a pile of vendor-specific `if` statements, which is how software slowly turns into archaeology.
