# Quicksilver Integration Fabric

The Integration Plane is a permanent, provider-neutral boundary between Quicksilver and external AI, API, development, design, project-management, build, deployment, and automation systems.

## Core principle

Agents are workers. The Integration Fabric is infrastructure.

An AI agent may run out of credits, disconnect, be replaced, or terminate. Quicksilver's work must not terminate with it. Durable task state and the event ledger live independently of the agent session.

```text
                    QUICKSILVER NEXUS
                           |
                    IntegrationRouter
                           |
                 +---------------------+
                 | Integration Fabric  |
                 +----------+----------+
                            |
          +-----------------+------------------+
          |                 |                  |
     Capability Graph   Task Store        Event Ledger
          |                 |                  |
          +-----------------+------------------+
                            |
                     Provider Gateway
                            |
       +----------+---------+---------+----------+
       |          |         |         |          |
      AI       GitHub    Linear    Google     Build/Deploy
       |          |         |         |          |
 OpenAI/etc     Repo      Issues    Drive     Figma/Replit/etc
```

## Durable work

Every multi-step operation should be converted into a task before consequential execution begins. A task contains only:

- objective
- capability plan
- provider/connector identifiers
- step status
- retry count
- timestamps
- safe error messages
- event correlation ID

It must never contain API keys, OAuth tokens, cookies, authorization headers, or other secrets.

Tasks are persisted locally by the Swift `IntegrationTaskStore`. The task can therefore be resumed by another agent or session.

## Event ledger

`IntegrationEventStore` provides an append-only local record of orchestration events. Events are metadata only and are intended for Nexus visibility, debugging, recovery, and audit correlation.

## Provider neutrality

Quicksilver requests capabilities, not vendors. A capability can have a primary, secondary, and fallback connector. Provider health, quota state, latency, and policy should eventually influence ranking without changing Swift application code.

## Security boundary

The iOS application does not own third-party secrets. Credentials belong in the managed integration gateway or OAuth flow. The Swift client carries only endpoint/session information and user-approved operation arguments.

Consequential capabilities require approval by default:

- repository/file writes
- pull requests and merges
- deployments
- external automation
- account/project mutations

Read-only operations can use automatic execution when policy permits.

## MCP and Noodle Seed

MCP is the transport abstraction for the current gateway. Noodle Seed is the first gateway implementation. It is deliberately replaceable. Quicksilver's domain layer depends on `IntegrationPlaneClient` and capability models, not on Noodle Seed internals.

This means the permanent asset is the Integration Fabric contract and durable state, not an agent's credits or a particular AI platform.

## Recovery flow

```text
Agent starts work
    -> create durable task
    -> execute step
    -> persist state/event
    -> provider fails or agent ends
    -> task remains queued/paused
    -> another agent/session discovers task
    -> resume from current step
```

## Current connector families

AI/LLM: OpenAI, Anthropic, Google AI, xAI.

Development: GitHub, Linear, Google, Cursor, Replit.

Design/build/deployment: Figma, Vercel, Netlify, Supabase, Convex, Lovable, AppDeploy, n8n.

The registry is intentionally extensible. Adding a provider should not require changing the Nexus UI or persona architecture.
