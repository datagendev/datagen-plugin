---
name: setup
description: Set up DataGen - authenticate and configure MCP tools
user_invocable: true
---

# DataGen Setup

Connect DataGen to Claude Code with zero-copy-paste authentication.

## When to invoke
- User mentions setting up DataGen or datagen
- User wants to configure DataGen tools
- SessionStart hook detects DataGen is not configured

## Before starting

**Create a task list first.** Use `TaskCreate` to create a task for each major step so the user can track progress. Mark each task `in_progress` when you start it and `completed` when done.

Tasks to create:
1. Check existing configuration
2. Authenticate with DataGen (skip if already configured)
3. Verify MCP connection
4. Install DataGen CLI
5. Install SDK (Python or TypeScript)
6. Create .datagen/ context folder
7. Setup complete -- show summary

## Important: Always run ALL steps

You MUST execute every step below, even if authentication is already configured. Steps 1-6 handle auth (skippable if working), but steps 7-9 MUST always be checked. Do NOT stop early after verifying auth -- always continue through CLI, SDK, and context folder checks.

## Steps

### 1. Check existing configuration

First, check if DataGen is already configured:

```bash
echo $DATAGEN_API_KEY
```

If the environment variable is set, verify the MCP connection works by calling the `searchTools` DataGen MCP tool with query "test". If it works, tell the user authentication and MCP are already configured, then **skip to step 7** (do NOT stop here).

If the variable is set but tools don't work, proceed to step 2 to reconfigure.

### 2. Create auth session

Create a new CLI auth session by calling the DataGen API:

```bash
curl -s -X POST https://app.datagen.dev/api/cli-auth/session | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['sessionToken'])"
```

Store the returned `sessionToken`.

### 3. Open browser

Open the authentication page in the user's browser. Do NOT prompt the user -- open automatically:

```bash
open "https://app.datagen.dev/cli-auth?session=SESSION_TOKEN"
```

Tell the user: "I've opened your browser. Sign up or log in to generate your API key. I'll detect when you're done."

### 4. Poll for completion

Poll the status endpoint every 3 seconds until completed or expired (max 10 minutes):

```bash
curl -s "https://app.datagen.dev/api/cli-auth/status?session=SESSION_TOKEN"
```

Expected responses:
- `{"status": "pending"}` -- keep polling
- `{"status": "completed", "api_key": "..."}` -- success, proceed to step 5
- `{"status": "expired"}` -- session expired, ask user to retry

### 5. Store API key

Once you receive the API key:

a. Add to shell profile:
```bash
echo 'export DATAGEN_API_KEY=THE_KEY' >> ~/.zshrc
export DATAGEN_API_KEY=THE_KEY
```

b. Configure the MCP server connection:
```bash
claude mcp add datagen --transport http https://mcp.datagen.dev/mcp -e DATAGEN_API_KEY
```

### 6. Verify connection

Test the connection by calling the DataGen MCP `searchTools` tool with query "email".

If it works, confirm setup is complete and suggest next steps:
- `/datagen:add-mcps` to connect services like Gmail, Slack, Linear
- `/datagen:deploy-agent` to create and deploy an agent
- Try asking about any tool: "search for CRM tools"

### 7. Install DataGen CLI

Check if the CLI is already installed:

```bash
which datagen
```

If not found, install based on platform:

**macOS/Linux:**
```bash
curl -fsSL https://cli.datagen.dev/install.sh | sh
```

**Windows (PowerShell):**
```powershell
irm https://cli.datagen.dev/install.ps1 | iex
```

After installation, verify it works:
```bash
datagen --help
```

If `which datagen` already succeeds, skip this step and tell the user the CLI is already installed.

### 8. Install SDK

The SDK allows Claude Code to call DataGen tools as native Python/TypeScript functions instead of going through MCP tool calls. This is significantly more token-efficient for multi-step workflows -- instead of each tool call consuming a full LLM round-trip, Claude can write a script that chains multiple tool calls in a single code execution.

Use the `AskUserQuestion` tool to ask the user which SDK they want to install. Provide three options:
- **Python SDK** (Recommended) -- creates a `.venv` if needed and installs `datagen-python-sdk`
- **TypeScript SDK** -- installs `@datagen-dev/typescript-sdk`
- **Skip** -- skip SDK installation (MCP tools still work without an SDK)

#### If Python SDK selected:

Check for an existing virtual environment (`.venv/`, `venv/`, or `$VIRTUAL_ENV`). If none exists, create one:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Then install:
```bash
pip install datagen-python-sdk
```

Requires Python >= 3.10, depends on `requests>=2.31.0`.

#### If TypeScript SDK selected:

Detect package manager from lockfile:
```bash
# If yarn.lock exists:
yarn add @datagen-dev/typescript-sdk
# If pnpm-lock.yaml exists:
pnpm add @datagen-dev/typescript-sdk
# Otherwise (default to npm):
npm install @datagen-dev/typescript-sdk
```

Requires Node >= 18. Zero runtime dependencies (uses native fetch).

### 9. Create `.datagen/` prompt context folder

Create a `.datagen/` directory in the project root with context files so Claude Code has DataGen knowledge in every session.

```bash
mkdir -p .datagen
```

**Create `.datagen/README.md`:**

```markdown
# DataGen Context

This folder provides DataGen context to Claude Code. These files are referenced from CLAUDE.md so Claude always knows how to use DataGen tools and SDKs in this project.

## Files

- **cli-commands.md** -- DataGen CLI command reference
- **skills.md** -- Available /datagen:* slash commands
- **sdk-usage.md** -- SDK usage, when to use SDK vs MCP, and quickstart for Python & TypeScript
```

**Create `.datagen/cli-commands.md`:**

```markdown
# DataGen CLI Commands

## Authentication
- `datagen login` -- save API key (opens browser for OAuth)
- `datagen mcp` -- configure DataGen MCP in local tools (Claude Code, Codex, Gemini)

## GitHub Integration
- `datagen github connect` -- install GitHub App and connect repos
- `datagen github status` -- check GitHub connection status
- `datagen github repos` -- list available repositories
- `datagen github connected` -- list connected repositories
- `datagen github connect-repo <owner/repo>` -- connect a specific repository
- `datagen github sync <repo-id>` -- re-sync agents from a repository

## Agent Management
- `datagen agents list` -- list discovered agents (flags: `--repo`, `--deployed`)
- `datagen agents show <agent-id>` -- show agent details and recent executions
- `datagen agents deploy <agent-id>` -- deploy an agent (creates webhook endpoint)
- `datagen agents undeploy <agent-id>` -- remove an agent deployment
- `datagen agents run <agent-id>` -- trigger execution (flag: `--payload '{...}'`)
- `datagen agents logs <agent-id>` -- view execution history (flag: `--limit N`)
- `datagen agents config <agent-id>` -- view/update config (flags: `--set-prompt`, `--secrets`, `--pr-mode`, `--add-recipient`, `--notify-success`, `--notify-failure`)
- `datagen agents schedule <agent-id>` -- manage cron schedules (flags: `--cron`, `--timezone`, `--name`, `--pause`, `--resume`, `--delete`)

## Secrets
- `datagen secrets list` -- list stored secrets (masked)
- `datagen secrets set KEY=value` -- create or update a secret
```

**Create `.datagen/skills.md`:**

```markdown
# DataGen Skills (Slash Commands)

Use these in Claude Code to interact with DataGen:

- `/datagen:setup` -- authenticate, install CLI/SDK, and configure MCP tools
- `/datagen:add-mcps` -- connect external services (Gmail, Slack, Linear, etc.)
- `/datagen:create-custom-tool` -- create a custom tool with your own logic
- `/datagen:deploy-agent` -- create agent definition and deploy as webhook/scheduled automation
- `/datagen:manage-agents` -- list, monitor, configure, and manage deployed agents
- `/datagen:code-mode` -- write local Python scripts using the SDK for bulk/multi-step workflows
```

**Create `.datagen/sdk-usage.md`:**

```markdown
# DataGen SDK Usage

## When to use what

- **DataGen MCP** -- interactive discovery/debugging:
  - `searchTools` to find the right tool alias
  - `getToolDetails` to confirm exact input schema
  - Quick one-off tool calls (1-3 calls)
- **Local scripts with SDK** (`/datagen:code-mode`) -- bulk/multi-step workflows:
  - Write and run a local Python/TypeScript script using the installed SDK
  - Use for batch processing (enrich 100 domains, process a CSV, chain 5+ tools)
  - Triggers when tool output is large -- write a script that calls the tool and saves results to local files (CSV, JSON, etc.) instead of dumping large output into context
- **`executeCode` MCP tool** -- ONLY for testing custom tools created via `/datagen:create-custom-tool`
  - Do NOT use `executeCode` for general workflows -- always use local scripts with the SDK instead

## Mental model (critical)

- You execute tools by alias name: `client.execute_tool("<tool_alias>", params)`
- Tool aliases are commonly:
  - `mcp_<Provider>_<tool_name>` for connected MCP servers (Gmail/Linear/Neon/etc.)
  - First-party DataGen tools like `listTools`, `searchTools`, `getToolDetails`
- Always be schema-first: confirm params via `getToolDetails` before calling a tool from code.

## Non-negotiable workflow

1. If you don't know the tool name: call `searchTools` via MCP first.
2. Before you call a tool from code: call `getToolDetails` and match the schema exactly.
3. Execute via SDK using the exact alias name you discovered.
4. Handle errors:
   - 401/403: missing/invalid API key OR the target MCP server isn't connected/authenticated in DataGen dashboard
   - 400/422: wrong params -- re-check `getToolDetails` and retry

---

## Python SDK

Requires Python >= 3.10 and `requests>=2.31.0`.

```bash
pip install datagen-python-sdk
```

```python
import os
from datagen_sdk import DatagenClient

if not os.getenv("DATAGEN_API_KEY"):
    raise RuntimeError("DATAGEN_API_KEY not set")

client = DatagenClient()

# Execute a tool
result = client.execute_tool(
    "mcp_Gmail_gmail_send_email",
    {
        "to": "user@example.com",
        "subject": "Hello",
        "body": "Hi from DataGen!",
    },
)
print(result)
```

### Discovery examples

```python
from datagen_sdk import DatagenClient

client = DatagenClient()

# List all tools
tools = client.execute_tool("listTools")

# Search by intent
matches = client.execute_tool("searchTools", {"query": "send email"})

# Get schema for a tool alias
details = client.execute_tool("getToolDetails", {"tool_name": "mcp_Gmail_gmail_send_email"})
```

---

## TypeScript SDK

Requires Node >= 18. Zero runtime dependencies (uses native fetch).

```bash
npm install @datagen-dev/typescript-sdk
```

```typescript
import { DatagenClient } from '@datagen-dev/typescript-sdk';

if (!process.env.DATAGEN_API_KEY) {
    throw new Error("DATAGEN_API_KEY not set");
}

const client = new DatagenClient();

// Execute a tool
const result = await client.executeTool(
    "mcp_Gmail_gmail_send_email",
    {
        to: "user@example.com",
        subject: "Hello",
        body: "Hi from DataGen!",
    }
);
console.log(result);
```

### Discovery examples

```typescript
import { DatagenClient } from '@datagen-dev/typescript-sdk';

const client = new DatagenClient();

// List all tools
const tools = await client.executeTool("listTools");

// Search by intent
const matches = await client.executeTool("searchTools", {
    query: "send email"
});

// Get schema for a tool alias
const details = await client.executeTool("getToolDetails", {
    tool_name: "mcp_Gmail_gmail_send_email"
});
```

---

## Configuration

Both SDKs read `DATAGEN_API_KEY` from the environment if no key is passed explicitly.
```

**Then append a DataGen section to the project's CLAUDE.md.**

Check if `CLAUDE.md` exists in the project root:

```bash
test -f CLAUDE.md && echo "exists" || echo "missing"
```

If it exists, append the DataGen section (only if it doesn't already contain a `## DataGen` section):

```bash
grep -q "## DataGen" CLAUDE.md || cat >> CLAUDE.md << 'DATAGEN_EOF'

## DataGen

This project uses [DataGen](https://datagen.dev) for AI agent tools and workflows.
See `.datagen/` for detailed context files:
- [CLI](.datagen/cli-commands.md) -- DataGen CLI commands
- [Skills](.datagen/skills.md) -- Available /datagen:* slash commands
- [SDK](.datagen/sdk-usage.md) -- SDK usage, when to use SDK vs MCP, and quickstart
DATAGEN_EOF
```

If it does not exist, create it:

```bash
cat > CLAUDE.md << 'DATAGEN_EOF'
# CLAUDE.md

## DataGen

This project uses [DataGen](https://datagen.dev) for AI agent tools and workflows.
See `.datagen/` for detailed context files:
- [CLI](.datagen/cli-commands.md) -- DataGen CLI commands
- [Skills](.datagen/skills.md) -- Available /datagen:* slash commands
- [SDK](.datagen/sdk-usage.md) -- SDK usage, when to use SDK vs MCP, and quickstart
DATAGEN_EOF
```

Tell the user: "Created `.datagen/` with DataGen context files and added a reference to your CLAUDE.md. Claude Code will now have DataGen knowledge in every session."

### 10. Setup complete

Print a status summary table showing the result of EVERY check:

| Component | Status |
|---|---|
| API Key (`DATAGEN_API_KEY`) | [set / not set] |
| MCP Connection | [working / configured / failed] |
| DataGen CLI | [installed / just installed / skipped] |
| SDK | [installed / just installed / skipped] |
| `.datagen/` context folder | [created / already exists / skipped] |
| `CLAUDE.md` DataGen section | [added / already exists / skipped] |

Then suggest next steps:
- `/datagen:add-mcps` to connect services like Gmail, Slack, Linear
- `/datagen:deploy-agent` to create and deploy an agent
- Try asking about any tool: "search for CRM tools"

### Error handling

- If browser fails to open: provide the URL for manual copy-paste
- If polling times out: suggest the user try again with `/datagen:setup`
- If MCP add fails: show the manual JSON config for `.claude/settings.json`
- If CLI install fails: provide the manual download link from https://github.com/datagendev/datagen-cli/releases
- If SDK install fails: suggest the user install manually and check their Python/Node version
- If `.datagen/` creation fails: check directory permissions and retry
