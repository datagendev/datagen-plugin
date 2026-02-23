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

### 2. Validate Claude Code credentials

Deployed agents need a Claude Code credential to run. Check if the user already has one stored in DataGen:

```bash
datagen secrets list 2>&1 | grep -iE "ANTHROPIC_API_KEY|CLAUDE_CODE_OAUTH_TOKEN"
```

**If NEITHER `ANTHROPIC_API_KEY` nor `CLAUDE_CODE_OAUTH_TOKEN` is found**, ask the user which approach they want:

**Option A: Use an Anthropic API key**
- The user provides their own `ANTHROPIC_API_KEY` from console.anthropic.com
- Push it to DataGen:
  ```bash
  datagen secrets set ANTHROPIC_API_KEY=<their-key>
  ```

**Option B: Use their Claude Code subscription (Claude Pro/Team/Enterprise)**
- This lets the deployed agent use their existing Claude subscription instead of paying for API credits separately.
- Tell the user to run the following command **in a separate terminal** (not in this Claude Code session):
  ```
  claude setup-token
  ```
- This generates a long-lived `CLAUDE_CODE_OAUTH_TOKEN`.
- Once they have the token, push it to DataGen:
  ```bash
  datagen secrets set CLAUDE_CODE_OAUTH_TOKEN
  ```
  (This reads from the local environment variable set by `claude setup-token`.)
- **Important**: `claude setup-token` is interactive and must be run in a regular terminal, not inside Claude Code.

**If one or both are already found**, confirm with the user which one the agent should use and move on.

### 3. Understand the agent

Ask the user what they want the agent to do:
- What task should it automate?
- What tools/services does it need?
- How should it be triggered? (webhook, schedule, manual)
- Should it create PRs or auto-merge changes?

### 4. Create agent definition

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

### 5. Push required secrets

Check if the agent needs any additional secrets (API keys for third-party services). For each required secret, check if it's already in DataGen:

```bash
datagen secrets list
```

For any missing secrets, push them:
```bash
# If the secret is already in the local environment:
datagen secrets set SECRET_NAME

# If the user provides the value directly:
datagen secrets set SECRET_NAME=<value>
```

Common secrets agents might need:
- `DATAGEN_API_KEY` -- DataGen platform access
- `INSTANTLY_API_KEY` -- Instantly email platform
- Service-specific API keys referenced by the agent

### 6. Connect GitHub repo (if needed)

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

### 7. Deploy the agent

```bash
datagen agents deploy <agent-name>
```

Configure deployment options:
- PR mode: `datagen agents config <agent-name> --pr-mode create_pr|auto_merge|skip`
- Secrets: `datagen agents config <agent-name> --add-secret SECRET_NAME`

### 8. Set up trigger

For scheduled execution:
```bash
datagen agents schedule <agent-name> --cron "0 9 * * 1-5"
```

For webhook trigger, the deploy command will output the webhook URL.

### 9. Test the deployment

```bash
datagen agents run <agent-name>
```

Check logs:
```bash
datagen agents logs <agent-name>
```

### 10. Verify and share

- Confirm the agent is running
- Share the webhook URL if applicable
- Suggest `/datagen:manage-agents` for ongoing management
