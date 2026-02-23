---
name: add-mcps
description: Connect external services (Gmail, Slack, Linear, etc.) to DataGen
user_invocable: true
---

# Add MCPs

Connect external MCP servers and services to expand your DataGen toolkit.

## When to invoke
- User wants to connect a service (Gmail, Slack, Linear, etc.)
- User says "add mcps", "connect", or mentions a specific service
- After initial setup, as a natural next step

## Before starting

**Create a task list first.** Use `TaskCreate` to create a task for each step so the user can track progress. Mark each task `in_progress` when you start it and `completed` when done.

Tasks to create:
1. Check DataGen is configured
2. Identify service to connect
3. Search and install MCP server
4. Handle OAuth (if needed)
5. Verify connection and show tools

## Steps

### 1. Check DataGen is configured

Verify `DATAGEN_API_KEY` is set. If not, suggest running `/datagen:setup` first.

### 2. Ask what to connect

Use `AskUserQuestion` to ask the user what service or capability they want to add. Common options:
- Gmail / Google Workspace
- Slack
- Linear
- GitHub
- Notion
- HubSpot
- Custom MCP server URL
- Or describe what they need (e.g., "I need to send emails")

### 3. Search built-in servers first

Always check DataGen's built-in server templates first using the `searchBuiltInServers` MCP tool:

```
searchBuiltInServers({ name: "linear" })
```

This returns pre-configured servers that DataGen can set up automatically. Each result includes:
- `template_id` -- use this to install
- `name`, `description`, `category`
- `required_fields` -- credentials needed (if any)

If a built-in server matches, proceed to **step 4a**.

If no built-in match is found, proceed to **step 4b**.

### 4a. Install a built-in server

First get full details about the server:

```
getBuiltInServerDetails({ template_id: "linear-mcp" })
```

This returns:
- All required and optional credential fields
- OAuth configuration (if applicable)
- Installation type and URL
- An `install_hint` showing the exact `addRemoteMcpServer` call to make

Then install it:

**OAuth-based servers** (Gmail, Slack, Linear, GitHub, etc.):
```
addRemoteMcpServer({ template_id: "linear-mcp" })
```
No credentials needed upfront -- the user will authenticate via browser.

**API-key-based servers**:
```
addRemoteMcpServer({
  template_id: "exa-search-mcp",
  credentials: { "API_KEY": "user-provided-key" }
})
```
Ask the user for required credentials before calling.

Then handle OAuth if needed (see **step 5**).

### 4b. Search online for MCP servers

If no built-in template exists, use Claude Code's `WebSearch` tool to find the latest MCP server for the service:
- Search for `"<service name> remote MCP server URL"` or `"<service name> MCP SSE endpoint"`
- Look for official remote MCP server URLs (ending in `/mcp` or `/sse`)
- If no official remote MCP server is available, search for hosted MCP platforms like smithery.ai or Klavis AI that may offer the service

Use `AskUserQuestion` to confirm the server URL and any required credentials with the user before connecting.

Then connect manually:

```
addRemoteMcpServer({
  server_name: "ServiceName",
  server_url: "https://mcp-server.example.com/mcp",
  env_args: { "API_KEY": "user-key" }
})
```

**Naming rules for manual mode:**
- Use only alphanumeric characters (no spaces, underscores, or dashes)
- Start with an uppercase letter
- Use CamelCase for multiple words
- Examples: "GitHub", "Slack", "GoogleDrive"

### 5. Handle OAuth (if needed)

If the response includes `requires_auth: true` and an `auth_url`:

1. Open the auth URL in the user's browser: `open "AUTH_URL"`
2. Tell the user to authorize the connection in their browser
3. Poll `checkRemoteMcpOauthStatus` with the returned `flow_id` until completed
4. Once OAuth completes, call `addRemoteMcpServer` again with the **same parameters** to finish the connection

### 6. Verify and show tools

Once connected, use `searchTools` to show the user what new tools are available from the connected service. The tools will be aliased as `mcp_<ServerName>_<tool_name>`.

### 7. Suggest next steps

- Connect more services with `/datagen:add-mcps`
- Try using the new tools immediately
- Use `/datagen:code-mode` for bulk workflows with these tools
- Deploy an agent that uses these tools with `/datagen:deploy-agent`

## Auth type detection

DataGen automatically detects authentication type:

**Token auth** (single-step) -- when `env_args` contains keys like:
- `API_KEY`, `BEARER_TOKEN`, `ACCESS_TOKEN`, `TOKEN`, `AUTHORIZATION`

**OAuth** (multi-step) -- when `env_args` contains keys like:
- `CLIENT_ID`, `CLIENT_SECRET`, `SCOPES`
- Or no token-like keys

## Transport detection

DataGen automatically detects transport from URL:
- URLs containing `/sse` or `events` -> SSE transport
- All other URLs -> HTTP transport

## Troubleshooting

- **Connection failures (404)**: Verify the server URL is correct and the MCP server is running
- **Invalid credentials**: Check API keys/tokens in `env_args` or `credentials`
- **OAuth expired**: Flows expire after 10-15 minutes. Start the process again.
- **OAuth pending after user completed**: Wait a few seconds and check status again.
- **No tools returned**: The server may not expose tools, or the user may lack required permissions.
