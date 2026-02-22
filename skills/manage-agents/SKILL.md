---
name: manage-agents
description: List, monitor, and manage deployed DataGen agents
user_invocable: true
---

# Manage Agents

View, monitor, and manage your deployed DataGen agents.

## When to invoke
- User wants to see their deployed agents
- User wants to check agent logs or status
- User wants to update, pause, or undeploy an agent

## Steps

### 1. Check prerequisites

Verify DataGen CLI is installed (`which datagen`). If not, guide installation.

### 2. List agents

Show all deployed agents:
```bash
datagen agents list
```

### 3. Based on user intent

**View logs:**
```bash
datagen agents logs <agent-name>
datagen agents logs <agent-name> --follow
```

**Check configuration:**
```bash
datagen agents config <agent-name>
```

**Update configuration:**
```bash
datagen agents config <agent-name> --pr-mode auto_merge
datagen agents config <agent-name> --add-secret NEW_SECRET
```

**Run manually:**
```bash
datagen agents run <agent-name>
datagen agents run <agent-name> --payload '{"key": "value"}'
```

**Update schedule:**
```bash
datagen agents schedule <agent-name> --cron "0 9 * * 1-5"
datagen agents schedule <agent-name> --disable
```

**Undeploy:**
```bash
datagen agents undeploy <agent-name>
```

### 4. Show status summary

After any action, show the current state of the agent including:
- Deployment status
- Last execution time and result
- Schedule (if any)
- Webhook URL (if deployed)
