---
name: run-tool
description: Quickly execute a DataGen tool by name
user_invocable: true
---

# Run Tool

Execute a DataGen tool directly with specified parameters.

## When to invoke
- User wants to run a specific tool quickly
- User says "run tool", "execute", or names a specific DataGen tool

## Steps

### 1. Check DataGen is configured

Verify DataGen MCP is connected. If not, suggest `/datagen:setup`.

### 2. Identify the tool

If the user specified a tool name, use it directly. Otherwise:
- Use the DataGen MCP `searchTools` tool to find relevant tools
- Show the user matching tools and let them pick

### 3. Get parameters

Check what parameters the tool requires using `getToolDetails`. Ask the user for any required inputs.

### 4. Execute

Use the DataGen MCP `executeTool` tool to run it with the provided parameters.

### 5. Show results

Display the tool output clearly. If the tool produces a file, code, or structured data, format it appropriately.
