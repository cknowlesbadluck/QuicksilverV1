# Quicksilver Integration Fabric

The Integration Fabric is Quicksilver's permanent, provider-neutral boundary to AI/LLM services, APIs, development platforms, project management, design, build/deployment, databases, and automation.

## Principle

**Agents are workers. The Integration Fabric is infrastructure.**

Claude, Grok, Codex, Cursor, ChatGPT, or any future agent may run out of credits, disconnect, or be replaced. The work state must survive the agent.

```text
Quicksilver Nexus
      |
IntegrationTaskCoordinator
      |
IntegrationRouter
      |
IntegrationGateway <---- stable application contract
      |
Noodle Seed / MCP gateway <---- replaceable transport
      |
Provider connectors
      |
AI | GitHub | Linear | Google | Figma | Replit | Vercel | Netlify | Supabase | ...
```

## Durable state

`IntegrationTaskStore` persists task objectives, planned steps, provider identifiers, status, retry count, timestamps, and safe errors. `IntegrationEventStore` keeps an append-only metadata ledger for task creation, pause/resume, recovery, and future audit correlation.

No task or event payload may contain credentials, bearer tokens, cookies, authorization headers, or raw secrets.

## Provider neutrality

The Nexus layer requests capabilities rather than vendors:

- chat, reason, code, search
- files, repo, issues, pull requests
- project management, design
- deploy, database, automation
- OAuth and custom API access

Routing can select primary, secondary, and fallback connectors without changing the Swift domain layer.

## Security

Third-party credentials remain outside the iOS binary. Consequential operations require approval by default, including repository/file writes, pull requests/merges, deployments, automation with external side effects, and account/project mutations.

## MCP / Noodle Seed

MCP is the current gateway protocol and Noodle Seed is the first gateway implementation. `IntegrationGateway` deliberately isolates that choice. Replacing Noodle Seed must not require rewriting Nexus, personas, memory, or UI code.

## Recovery

```text
Agent begins task
 -> durable task created
 -> step executes
 -> state/event persisted
 -> agent terminates or provider fails
 -> task remains recoverable
 -> another agent/session resumes it
```

## Current scope

The repository contains the provider registry, capability routing/planning tools, MCP transport, credential-safe health surface, durable Swift task/event stores, provider-neutral gateway contract, orchestration coordinator, and contract tests.

Concrete provider credentials and production connector accounts are intentionally configured outside source control. The gateway implementation must be validated with Noodle Seed tooling and real OAuth/API credentials before production execution is enabled.
