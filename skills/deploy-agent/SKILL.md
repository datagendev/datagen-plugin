---
name: deploy-agent
description: Create, deploy, and manage DataGen agents with webhooks and schedules
user_invocable: true
---

# Deploy Agent

Develop an agent definition and deploy it as a webhook-triggered or scheduled automation.

## When to invoke
- User wants to create, deploy, or manage an agent
- User mentions automation, scheduling, webhooks, or deploying
- User wants to run an agent on a schedule or trigger

## Steps

### 1. Check prerequisites

- Verify `DATAGEN_API_KEY` is set (suggest `/datagen:setup` if not)
- Check if the DataGen CLI is installed: `which datagen`
- If CLI is not installed, guide installation:
  ```bash
  # macOS
  brew tap datagen-dev/tap && brew install datagen
  # or direct download
  curl -fsSL https://cli.datagen.dev/install.sh | sh
  ```

### 2. Understand the agent

Ask the user what they want the agent to do:
- What task should it automate?
- What tools/services does it need?
- How should it be triggered? (webhook, schedule, manual)
- Should it create PRs or auto-merge changes?

### 3. Create agent definition

Help the user create an agent markdown file at `.claude/agents/<agent-name>.md`:

```markdown
---
name: Agent Name
description: What the agent does
tools: [tool1, tool2]
---

# Agent Instructions

Describe what the agent should do when triggered...
```

### 4. Connect GitHub repo (if needed)

If the user wants to deploy:

a. Login to DataGen CLI:
```bash
datagen login
```

b. Connect GitHub (if not already):
```bash
datagen github connect
```

c. Add the repo:
```bash
datagen github repos add
```

d. Sync to discover agents:
```bash
datagen github repos sync
```

### 5. Deploy the agent

```bash
datagen agents deploy <agent-name>
```

Configure deployment options:
- PR mode: `datagen agents config <agent-name> --pr-mode create_pr|auto_merge|skip`
- Secrets: `datagen agents config <agent-name> --add-secret SECRET_NAME`

### 6. Set up trigger

For scheduled execution:
```bash
datagen agents schedule <agent-name> --cron "0 9 * * 1-5"
```

For webhook trigger, the deploy command will output the webhook URL.

### 7. Test the deployment

```bash
datagen agents run <agent-name>
```

Check logs:
```bash
datagen agents logs <agent-name>
```

### 8. Verify and share

- Confirm the agent is running
- Share the webhook URL if applicable
- Suggest `/datagen:manage-agents` for ongoing management
