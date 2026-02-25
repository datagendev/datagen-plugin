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

## Before starting

**Create a task list first.** Use `TaskCreate` to create a task for each step below so the user can track progress. Mark each task `in_progress` when you start it and `completed` when done.

For deploying an existing agent, create these tasks:
1. Check prerequisites (CLI + API key)
2. Read agent file and scan dependencies
3. Validate Claude Code credentials
4. Push required secrets
5. Connect GitHub repo
6. Deploy the agent
7. Set up trigger
8. Test the deployment

For creating + deploying a new agent, also add before step 5:
- Understand agent requirements
- Create agent definition

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

### 2. Read the agent file and scan dependencies

Read the agent `.md` file the user wants to deploy. If they haven't specified one, look in `.claude/agents/` and ask which one.

**2a. Find dependent scripts**

Scan the agent file for referenced scripts -- look for patterns like:
- `python3 scripts/*.py` or `python *.py`
- `source .venv/bin/activate && python ...`
- `PYTHONPATH=scripts python3 scripts/*.py`
- `.claude/skills/*/scripts/*.py`
- `bash *.sh` or `sh *.sh`

Collect all unique script paths referenced in the agent file.

**2b. Scan scripts for required secrets**

For each script found, read the file and grep for secret/credential patterns:
- `os.getenv("..._API_KEY")` or `os.environ.get("..._API_KEY")`
- `os.getenv("..._TOKEN")` or `os.environ.get("..._TOKEN")`
- `os.getenv("..._SECRET")` or `os.environ.get("..._SECRET")`

Also scan the agent `.md` file itself for:
- `DATAGEN_API_KEY`, `ANTHROPIC_API_KEY`, or any `*_API_KEY` mentions
- Environment variable references like `` `SOME_SECRET` `` or `export SOME_SECRET`

**2c. Build the dependency report**

Combine findings and present to the user:

```
Agent: <agent-name>
Scripts: <list of script paths>
Required secrets: <list of env var names found>
```

Example output:
```
Agent: instantly-health-report
Scripts:
  - .claude/skills/instantly-analytics/scripts/fetch_data.py
  - .claude/skills/instantly-analytics/scripts/report_domain_health.py
  - .claude/skills/instantly-analytics/scripts/report_campaign_perf.py
  - .claude/skills/instantly-analytics/scripts/report_inbox_status.py
  - .claude/skills/instantly-analytics/scripts/build_report_html.py
Required secrets:
  - DATAGEN_API_KEY (from agent.md)
  - INSTANTLY_API_KEY (from fetch_data.py)
```

### 3. Validate Claude Code credentials

Deployed agents need a Claude Code credential to run. Check what's already stored in DataGen:

```bash
datagen secrets list 2>&1 | grep -iE "ANTHROPIC_API_KEY|CLAUDE_CODE_OAUTH_TOKEN"
```

**If BOTH `ANTHROPIC_API_KEY` and `CLAUDE_CODE_OAUTH_TOKEN` are found**, ask the user which one the agent should use (use `AskUserQuestion`):

- **Anthropic API Key** -- uses API credits from console.anthropic.com
- **Claude Code OAuth Token** -- uses their existing Claude Pro/Team/Enterprise subscription

Then move on.

**If only ONE is found**, confirm with the user that the agent should use the existing credential and move on.

**If NEITHER is found**, ask the user which approach they want:

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

### 4. Push all required secrets

Cross-check the secrets discovered in step 2 against what's already in DataGen:

```bash
datagen secrets list
```

For each secret found in step 2 that is NOT in `datagen secrets list`, prompt the user to push it:

```bash
# If the secret is already in the local environment:
datagen secrets set SECRET_NAME

# If the user provides the value directly:
datagen secrets set SECRET_NAME=<value>
```

Do not proceed to deployment until all required secrets are stored. Summarize:
```
Secrets status:
  DATAGEN_API_KEY        -- stored
  CLAUDE_CODE_OAUTH_TOKEN -- stored
  INSTANTLY_API_KEY      -- stored
  All secrets ready.
```

### 5. Understand the agent (if creating new)

If the user is deploying an existing agent, skip to step 7.

If creating a new agent, ask:
- What task should it automate?
- What tools/services does it need?
- How should it be triggered? (webhook, schedule, manual)
- Should it create PRs or auto-merge changes?

### 6. Create agent definition (if creating new)

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

After creating, re-run step 2 to scan for dependencies.

### 7. Connect GitHub repo (if needed)

**7a. Ensure the repo exists on GitHub**

Check if the current project is a git repo with a remote:
```bash
git remote -v
```

If no remote or no GitHub repo exists:
- Initialize git if needed: `git init`
- Create the repo: `gh repo create <org>/<repo-name> --private --source=. --push`
- If the remote already exists but hasn't been pushed: `git push -u origin main`

**7b. Check if the GitHub App has access to this repo**

```bash
datagen github repos
```

If the repo is NOT listed, the DataGen GitHub App doesn't have access yet. Run:
```bash
datagen github connect
```
This opens the browser to the GitHub App installation settings where the user can add the new repo to the app's repository access. Wait for the user to confirm they've added it, then verify:
```bash
datagen github repos
```

**7c. Connect the repo to DataGen**

Once the repo appears in `datagen github repos`, connect it:
```bash
datagen github connect-repo <owner/repo>
```

This scans `.claude/agents/*.md` and discovers agent definitions. If it returns "already connected", that's fine -- proceed.

**7d. Verify agent discovery**

```bash
datagen github connected
```

Check that the repo shows `SYNCED` status and the expected agent count. If the agent count is 0 or wrong, trigger a manual sync:
```bash
datagen github sync <repo-id>
```

**7e. Confirm the agent is listed**

```bash
datagen agents list --repo <owner/repo>
```

This shows the agent ID needed for deployment in the next step.

### 8. Deploy the agent

Use the agent ID from step 7e:

```bash
datagen agents deploy <agent-id>
```

This creates a webhook endpoint and returns the webhook URL.

Then configure the agent with secrets discovered in step 2 (comma-separated):
```bash
datagen agents config <agent-id> --secrets "DATAGEN_API_KEY,CLAUDE_CODE_OAUTH_TOKEN"
```

Optionally set PR mode:
```bash
datagen agents config <agent-id> --pr-mode create_pr|auto_merge|skip
```

### 9. Set up trigger

Ask the user how they want to trigger the agent. Use `AskUserQuestion` with options:
- **Daily schedule** -- runs on a cron schedule (e.g., every weekday at 9am)
- **Webhook only** -- triggered via HTTP POST to the webhook URL
- **Both** -- scheduled + can also be triggered manually via webhook

For scheduled execution:
```bash
datagen agents schedule <agent-id> --cron "0 9 * * 1-5" --timezone "America/Chicago" --name "descriptive name"
```

Common cron patterns:
- `0 9 * * 1-5` -- weekdays at 9am
- `0 9 * * *` -- every day at 9am
- `0 */6 * * *` -- every 6 hours
- `0 9 * * 1` -- every Monday at 9am

For webhook trigger, the deploy command in step 8 already output the webhook URL.

### 10. Test the deployment

```bash
datagen agents run <agent-id>
```

Check logs:
```bash
datagen agents logs <agent-id>
```

### 11. Verify and share

- Confirm the agent is running
- Share the webhook URL if applicable
- Suggest `/datagen:manage-agents` for ongoing management
