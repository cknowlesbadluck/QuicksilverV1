# Quicksilver Integration Plane Architecture

## Purpose

The Integration Plane is the universal integration boundary for Quicksilver. It keeps the iOS application independent of individual AI vendors and development platforms while allowing Quicksilver to orchestrate them as a single capability graph.

## Architecture

```text
                         QUICKSILVER
                              |
                    Intent / Orchestration
                              |
                    +-------------------+
                    | Integration Plane |
                    +-------------------+
                       /       |       \
                 routing   policy     context
                    |         |          |
              +-----+---------+----------+-----+
              |                               |
         AI / LLM                         Developer
      OpenAI / Claude                   GitHub / Linear
       Gemini / Grok                    Google / Cursor
              |                               |
              +---------------+---------------+
                              |
                       Build / Deploy
                 Figma / Replit / Vercel
              Netlify / Supabase / n8n / etc.
                              |
                         Result / Event
                              |
                         Quicksilver UI
```

## Capability abstraction

Quicksilver should ask for capabilities rather than vendors:

- `chat`
- `reason`
- `code`
- `search`
- `files`
- `repo`
- `issues`
- `pull-requests`
- `project-management`
- `design`
- `deploy`
- `database`
- `automation`
- `oauth`
- `custom-api`

A route may contain a primary, secondary, and fallback provider. This lets the plane survive unavailable providers, quota exhaustion, or connector failures without changing application code.

## Security boundary

The iOS app must never contain third-party service secrets. The integration plane owns downstream credentials through managed secret/OAuth mechanisms. Tool payloads must contain references, identifiers, or user-approved arguments, never bearer tokens or raw secret values.

High-impact operations require approval before execution:

- repository writes
- pull-request creation or merge
- file mutations
- deployments
- account or project changes
- automation with external side effects

## Agent interoperability

MCP is the primary protocol. A single Noodle Seed endpoint can be exposed to MCP-capable clients instead of maintaining separate integrations for every AI host. Noodle Seed documents this as the path to making a capability available across ChatGPT, Claude, coding agents, and other MCP clients. 

## Swift boundary

The Swift side uses `IntegrationPlaneClient`, an actor-isolated transport layer. The client should remain unaware of vendor-specific authentication and implementation details.

Recommended application flow:

```text
Quicksilver intent
  -> IntegrationRouter
  -> IntegrationPlaneClient
  -> MCP tool
  -> connector
  -> governed operation
  -> structured result
  -> Swift domain model
  -> UI / persona / memory
```

## Next implementation layers

1. Replace the static connector registry with Noodle-managed connector configuration.
2. Add OAuth-backed GitHub, Linear, and Google operations.
3. Add managed API credentials for AI providers.
4. Add provider health and latency scoring to routing.
5. Add retry, timeout, circuit-breaker, and quota-aware fallback logic.
6. Add approval events and audit correlation IDs.
7. Add Quicksilver-specific tool groups for coding, repository management, project management, design handoff, and deployment.
8. Add automated contract tests for each connector.
