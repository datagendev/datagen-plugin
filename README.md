# DataGen — Claude Code Plugin

**50+ MCP tools for AI agent workflows, right inside Claude Code.**

DataGen is a Claude Code plugin that connects your AI workflows to the services that power your work. Search tools, connect services via OAuth, execute actions, and deploy autonomous agents — all without leaving your editor.

---

## What It Does

Claude is great at reasoning. DataGen gives it hands.

With the DataGen plugin installed, Claude can discover and run tools across dozens of real-world services — sending emails, querying databases, scraping the web, creating GitHub issues, enriching leads, and more. You can also deploy autonomous agents that run on a schedule, respond to webhooks, or trigger on pull requests.

---

## Key Features

### Tool Discovery & Execution
Search 50+ MCP tools by keyword or use case. Get parameter details, chain tools into multi-step workflows, and execute them directly from Claude Code.

### One-Click Service Connections
Connect Gmail, Slack, GitHub, Notion, HubSpot, Linear, LinkedIn, and more via OAuth — no credential copy-pasting required. Add any custom MCP server too.

### Agent Deployment
Write an agent definition in Markdown, then deploy it as an autonomous agent that runs on a cron schedule, responds to webhooks, or automates GitHub PR workflows.

### Agent Management
List, monitor, update, and undeploy your agents. Check logs, change schedules, update secrets, and trigger manual runs — all from within Claude Code.

---

## Tool Categories

| Category | Tools |
|---|---|
| Web & Search | Firecrawl, Perplexity, web scraping |
| Communication | Gmail, Slack, email |
| CRM & Sales | HubSpot, LinkedIn, lead enrichment |
| Development | GitHub, Linear, code execution |
| Data | CSV processing, database queries, file operations |
| Custom | Connect any MCP server |

---

## Skills

| Skill | What it does |
|---|---|
| `/datagen:setup` | Authenticate and configure the DataGen MCP connection |
| `/datagen:add-tools` | Connect a new service or MCP server |
| `/datagen:run-tool` | Find and execute a specific tool |
| `/datagen:deploy-agent` | Deploy an autonomous agent from a Markdown definition |
| `/datagen:manage-agents` | View, update, and control deployed agents |

---

## Getting Started

1. Install the plugin and run `/datagen:setup`
2. A browser window opens for authentication — no copy-pasting
3. Ask Claude to find tools for your use case, or run `/datagen:add-tools` to connect a service
4. Build workflows, deploy agents, automate your stack

---

## Links

- Website: [datagen.dev](https://datagen.dev)
- Repository: [github.com/datagen-dev/datagen-plugin](https://github.com/datagen-dev/datagen-plugin)
