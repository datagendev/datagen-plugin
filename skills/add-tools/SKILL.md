---
name: add-tools
description: Connect external services (Gmail, Slack, Linear, etc.) to DataGen
user_invocable: true
---

# Add Tools

Connect external MCP servers and services to expand your DataGen toolkit.

## When to invoke
- User wants to connect a service (Gmail, Slack, Linear, etc.)
- User says "add tools", "connect", or mentions a specific service
- After initial setup, as a natural next step

## Steps

### 1. Check DataGen is configured

Verify `DATAGEN_API_KEY` is set. If not, suggest running `/datagen:setup` first.

### 2. Ask what to connect

Ask the user which service they want to connect. Common options:
- Gmail / Google Workspace
- Slack
- Linear
- GitHub
- Notion
- HubSpot
- Custom MCP server URL

### 3. Connect the service

Use the DataGen MCP tool `addRemoteMcpServer` to initiate the connection:
- Pass the service name or MCP server URL
- The tool will return an OAuth URL if authentication is required

### 4. Handle OAuth (if needed)

If an OAuth URL is returned:
1. Open it in the user's browser: `open "URL"`
2. Tell the user to authorize the connection in their browser
3. Use `checkRemoteMcpOauthStatus` to poll for completion

### 5. Verify and show tools

Once connected, use `searchTools` to show the user what new tools are available from the connected service.

### 6. Suggest next steps

- Connect more services with `/datagen:add-tools`
- Try using the new tools immediately
- Deploy an agent that uses these tools with `/datagen:deploy-agent`
