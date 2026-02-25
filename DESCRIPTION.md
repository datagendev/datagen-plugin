# DataGen Plugin — Detailed Description

## Overview

**DataGen** is a Claude Code plugin that integrates the DataGen platform directly into the Claude Code IDE. It provides a curated set of 50+ MCP (Model Context Protocol) tools and a guided skill-based workflow system that enables users to discover, connect, build, deploy, and manage AI agents — all without leaving their editor.

- **Plugin name:** `datagen`
- **Version:** 1.0.0
- **Author:** DataGen
- **Homepage:** https://datagen.dev
- **Repository:** https://github.com/datagen-dev/datagen-plugin

---

## Purpose

The plugin solves a common problem in AI agent development: the friction involved in wiring together external services, designing agent logic, and taking agents to production. DataGen abstracts all of that into a single, unified workflow accessible through slash commands inside Claude Code.

At its core, the plugin does four things:

1. **Connects services** — OAuth and API-key flows for Gmail, Slack, GitHub, Linear, HubSpot, Notion, Firecrawl, Perplexity, and dozens more.
2. **Builds agents** — Guided interviews, tool discovery, data modelling, and prototyping culminating in a deployable agent definition.
3. **Deploys agents** — Packages agents as webhooks or scheduled automation with secrets management and GitHub integration.
4. **Manages agents** — Lists, monitors, reconfigures, and re-deploys live agents from within the IDE.

---

## Architecture

The plugin follows the **Claude Code plugin specification**: a `plugin.json` manifest pointing to skill directories, an `.mcp.json` file declaring the remote MCP server, and a `hooks.json` file wiring up lifecycle hooks.

```
datagen-plugin/
├── .claude-plugin/
│   ├── plugin.json          # Plugin metadata + skill registry
│   └── marketplace.json     # Marketplace listing
├── .mcp.json                # HTTP MCP server connection
├── hooks/
│   └── hooks.json           # SessionStart + PostToolUse hooks
├── agents/
│   └── datagen-helper.md    # Domain-knowledge subagent
├── skills/                  # 8 user-invocable skills
│   ├── setup/
│   ├── add-mcps/
│   ├── build-agent/
│   ├── deploy-agent/
│   ├── manage-agents/
│   ├── fetch-agent/
│   ├── create-custom-tool/
│   └── code-mode/
└── scripts/
    └── validate-agent-frontmatter.sh
```

### MCP Server

All 50+ tools are served over HTTP by the DataGen cloud backend:

```json
{
  "mcpServers": {
    "datagen": {
      "type": "http",
      "url": "https://mcp.datagen.dev/mcp",
      "headers": { "X-API-Key": "${DATAGEN_API_KEY}" }
    }
  }
}
```

Authentication is handled via the `DATAGEN_API_KEY` environment variable, which is obtained through the `/datagen:setup` OAuth flow.

### Lifecycle Hooks

Two hooks fire automatically throughout a session:

| Hook | Trigger | Behaviour |
|------|---------|-----------|
| `SessionStart` | Every new Claude Code session | Checks whether `DATAGEN_API_KEY` is set; if not, suggests running `/datagen:setup` in a single, non-intrusive line. |
| `PostToolUse` (Write/Edit) | After any file write or edit | Runs `validate-agent-frontmatter.sh` to enforce correct YAML frontmatter on agent definition files. |

---

## Skills (Slash Commands)

Each skill is a Markdown file with YAML frontmatter and a task-driven prompt. Users invoke them as `/datagen:<skill-name>`.

### `/datagen:setup`
Walks the user through full onboarding in 10 steps:
1. Browser-based OAuth to obtain an API key (zero copy-paste).
2. MCP server connection verification (`searchTools` smoke test).
3. CLI installation (macOS Homebrew, Linux curl, Windows scoop).
4. Python and TypeScript SDK installation.
5. Creation of a `.datagen/` context folder containing a README, CLI cheatsheet, skills catalogue, and SDK usage guide.

### `/datagen:add-mcps`
Connects external services to the DataGen toolbox:
- **Built-in servers** — searched by name via `searchBuiltInServers`; each has its own OAuth or API-key flow.
- **Custom servers** — any MCP server reachable by URL can be added with `addRemoteMcpServer`.
- Supports services including Gmail, Slack, Linear, GitHub, HubSpot, Notion, Firecrawl, Perplexity, Exa Search, and more.

### `/datagen:build-agent`
Five-phase guided workflow for building a production-ready agent:
1. **Interview** — 5 structured questions covering purpose, triggers, tools, data sources, and output.
2. **Tool exploration** — Uses `searchTools` and `getToolDetails` to map intent to concrete tool schemas before writing any code.
3. **Data modelling** — Designs the entity lifecycle the agent will manage.
4. **Prototyping** — Writes and runs Python/TypeScript scripts using the DataGen SDK to validate each tool call.
5. **Agent definition** — Produces a `.claude/agents/<name>.md` file with YAML frontmatter and a full multi-step orchestration prompt.

### `/datagen:deploy-agent`
11-step deployment workflow:
1. Scans agent definition for referenced scripts and secrets.
2. Walks through secret creation with `datagen secrets set`.
3. Connects the project's GitHub repository via `datagen github connect`.
4. Deploys the agent with `datagen agents deploy`.
5. Configures the agent as a **webhook** (returns an HTTPS URL) or **scheduled job** (cron-based).
6. Provides a deployment summary with IDs, URLs, and next steps.

### `/datagen:manage-agents`
Exposes full lifecycle management for deployed agents:
- `datagen agents list` — list all deployed agents with status.
- `datagen agents logs <id>` — tail execution logs.
- `datagen agents config <id>` — view/update configuration.
- `datagen agents deploy` — re-deploy after changes.
- `datagen agents delete <id>` — remove an agent.

### `/datagen:fetch-agent`
Downloads pre-built agent templates from the `datagen-agent-templates` GitHub repository:
1. Reads a `manifest.json` listing all available templates.
2. Presents templates with names, descriptions, and prerequisites.
3. Downloads all required files (agent definition, scripts, helper files).
4. Rewrites relative paths inside agent definitions to match the local project layout.
5. Reports any missing secrets the template requires.

### `/datagen:create-custom-tool`
Lets users build their own DataGen tools with custom logic:
- Writes the tool's business logic.
- Registers the tool via `updateCustomTool`.
- Tests execution with `executeCode` and `checkRunStatus`.
- The tool then becomes available to any agent via the standard `executeTool` MCP interface.

### `/datagen:code-mode`
Switches to local script execution mode for **bulk workflows**:
- Scaffolds Python or TypeScript scripts that use the DataGen SDK.
- Scripts call the same 50+ tools as agents but run locally, making them suitable for batch processing, data migration, and ad-hoc automation.
- Example pattern:
  ```python
  from datagen_sdk import DatagenClient
  client = DatagenClient()
  result = client.execute_tool("mcp_Gmail_gmail_send_email", {
      "to": "user@example.com",
      "subject": "Hello",
      "body": "Sent from a DataGen script."
  })
  ```

---

## Agent Definition Format

Agents built with this plugin are stored as Markdown files at `.claude/agents/<name>.md` with YAML frontmatter. The `validate-agent-frontmatter.sh` hook enforces the following schema after every file write:

**Required fields:**
- `name` — lowercase letters and hyphens only.
- `description` — free text.

**Optional fields:**

| Field | Allowed values |
|-------|---------------|
| `tools` | list of allowed MCP tool names |
| `disallowedTools` | list of blocked MCP tool names |
| `model` | `sonnet`, `opus`, `haiku`, `inherit` |
| `permissionMode` | `default`, `acceptEdits`, `dontAsk`, `bypassPermissions`, `plan` |
| `maxTurns` | integer |
| `skills` | list of skill paths |
| `mcpServers` | MCP server config map |
| `hooks` | hooks configuration |
| `memory` | `user`, `project`, `local` |
| `background` | `true` or `false` |
| `isolation` | `worktree` |

---

## Key Design Principles

**Agent as Orchestrator** — Agents handle reasoning and coordination; compute-heavy work is delegated to scripts. This keeps context windows small and agent logic clean.

**RLM (Reason–Loop–Memory) Pattern** — Data flows through files (`tmp/` for intermediate results, `.datagen/` for persistent context), not through agent memory, so large datasets never bloat the context.

**Schema-First Tool Discovery** — Every workflow calls `searchTools` and `getToolDetails` before executing any tool. This ensures correct parameter names, types, and constraints are used.

**Task-Driven UX** — Every skill creates a `TodoWrite` task list at the start so users can track progress across multi-step workflows.

**Validation at Write Time** — The PostToolUse hook blocks malformed agent definitions immediately, preventing runtime errors from invalid frontmatter.

---

## Available MCP Tools (Categories)

| Category | Example services |
|----------|-----------------|
| Communication | Gmail, Slack |
| CRM / Sales | HubSpot, LinkedIn |
| Project management | Linear, GitHub, Notion |
| Web intelligence | Firecrawl, Perplexity, Exa Search |
| Data processing | CSV tools, database queries |
| Custom | User-defined tools via `create-custom-tool` |

Core tool API exposed to agents and scripts:

| Tool | Purpose |
|------|---------|
| `searchTools(query)` | Find tools by natural-language intent |
| `getToolDetails(tool_name)` | Retrieve full JSON schema for a tool |
| `executeTool(name, params)` | Invoke any tool synchronously |
| `searchBuiltInServers(name)` | Discover pre-built MCP server integrations |
| `addRemoteMcpServer(...)` | Connect a custom MCP server |
| `listTools()` | List all available tools |
| `updateCustomTool(...)` | Create or update a custom tool |
| `submitCustomToolRun(...)` | Asynchronously execute a custom tool |
| `checkRunStatus(run_id)` | Poll the status of an async tool run |

---

## Summary

The DataGen plugin turns Claude Code into a full AI agent development environment. It handles the entire lifecycle — authentication, service connectivity, agent design, prototyping, deployment, and ongoing management — through eight composable slash commands backed by a hosted MCP server with 50+ pre-built tool integrations. Its hook system ensures configuration is always present and agent definitions are always valid, while its SDK support lets users break out of the IDE for bulk scripting workloads when needed.
