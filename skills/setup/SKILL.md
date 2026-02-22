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

## Steps

### 1. Check existing configuration

First, check if DataGen is already configured:

```bash
echo $DATAGEN_API_KEY
```

If the environment variable is set, verify the MCP connection works by calling the `searchTools` DataGen MCP tool with query "test". If it works, tell the user DataGen is already configured and suggest:
- `/datagen:add-tools` to connect more services
- `/datagen:deploy-agent` to deploy an agent

If the variable is set but tools don't work, proceed to reconfigure.

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
- `/datagen:add-tools` to connect services like Gmail, Slack, Linear
- `/datagen:deploy-agent` to create and deploy an agent
- Try asking about any tool: "search for CRM tools"

### Error handling

- If browser fails to open: provide the URL for manual copy-paste
- If polling times out: suggest the user try again with `/datagen:setup`
- If MCP add fails: show the manual JSON config for `.claude/settings.json`
