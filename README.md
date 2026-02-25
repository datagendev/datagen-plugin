# DataGen Plugin for Claude Code

A Claude Code plugin that gives you 50+ MCP tools for AI agent workflows -- build, deploy, and manage agents directly from your terminal.

## Install

From your terminal:

```bash
claude plugin marketplace add datagendev/datagen-plugin
claude plugin install datagen --scope project
```

Or from inside Claude Code:

```
/plugin marketplace add datagendev/datagen-plugin
/plugin install datagen --scope project
```

## Setup

After installing the plugin, run the setup command inside Claude Code:

```
/datagen:setup
```

This will:
1. Open your browser to authenticate with DataGen
2. Store your API key
3. Configure the MCP server connection
4. Install the DataGen CLI
5. Optionally install the Python or TypeScript SDK

## Slash Commands

| Command | Description |
|---------|-------------|
| `/datagen:setup` | Authenticate, install CLI/SDK, and configure MCP tools |
| `/datagen:add-mcps` | Connect external services (Gmail, Slack, Linear, etc.) |
| `/datagen:build-agent` | Build a new agent from scratch with a guided workflow |
| `/datagen:deploy-agent` | Deploy an agent as a webhook or scheduled automation |
| `/datagen:manage-agents` | List, monitor, and manage deployed agents |
| `/datagen:fetch-agent` | Browse and install pre-built agent templates |
| `/datagen:fetch-skill` | Browse and install reusable skills |
| `/datagen:create-custom-tool` | Create a custom tool with your own logic |
| `/datagen:code-mode` | Write local Python scripts using the SDK for bulk workflows |

## What's Inside

```
.claude-plugin/
  plugin.json          # Plugin manifest

skills/                # Slash command definitions
  setup/               # Authentication and configuration
  add-mcps/            # Connect external services
  build-agent/         # Guided agent creation (interview -> explore -> model -> prototype -> define)
  deploy-agent/        # Push agents to DataGen cloud with webhooks/schedules
  manage-agents/       # Monitor and configure deployed agents
  fetch-agent/         # Install pre-built agent templates
  fetch-skill/         # Install reusable skills
  create-custom-tool/  # Build custom tools
  code-mode/           # SDK-based scripting for bulk operations

agents/
  datagen-helper.md    # Subagent with DataGen domain knowledge

hooks/
  hooks.json           # SessionStart check + agent frontmatter validation

scripts/
  install-skill.py     # Skill installer
  validate-agent-frontmatter.sh  # PostToolUse hook for agent file validation
```

## How It Works

The plugin connects Claude Code to the [DataGen](https://datagen.dev) platform via MCP (Model Context Protocol). This gives Claude access to tools for:

- **Web and search** -- Firecrawl, Perplexity, web scraping
- **Communication** -- Gmail, Slack, email tools
- **CRM and sales** -- HubSpot, LinkedIn, lead enrichment
- **Development** -- GitHub, Linear, code execution
- **Data** -- CSV processing, database queries, file operations
- **Custom** -- connect any MCP server or build your own tools

## Agent Development Workflow

The plugin supports a full agent lifecycle:

1. **Build** (`/datagen:build-agent`) -- interview, explore tools, model data, prototype scripts, write the agent definition
2. **Test** -- run the agent locally in Claude Code
3. **Deploy** (`/datagen:deploy-agent`) -- push to GitHub, connect to DataGen, set up webhooks or cron schedules
4. **Manage** (`/datagen:manage-agents`) -- view logs, update config, pause/resume schedules

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) version 1.0.33 or later (`claude --version` to check)
- A DataGen account ([datagen.dev](https://datagen.dev))

## Links

- [DataGen Platform](https://datagen.dev)
- [DataGen Documentation](https://docs.datagen.dev)
- [Agent Templates](https://github.com/datagendev/datagen-agent-templates)
