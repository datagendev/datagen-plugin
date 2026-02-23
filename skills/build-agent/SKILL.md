---
name: build-agent
description: Walk through building a new DataGen agent from scratch -- interview, prototype, explore tools, model data, and write the agent definition
user_invocable: true
---

# Build Agent

Guide the user through building a new Claude Code agent from scratch, from understanding the job to having a working agent locally. This skill covers the full build lifecycle -- deploy is handled separately by `/datagen:deploy-agent`.

## When to invoke
- User wants to create or build a new agent
- User mentions "build agent", "create agent", "new agent", or "agent from scratch"
- User has a workflow they want to automate and needs help structuring it as an agent

## Before starting

**Create a task list first.** Use `TaskCreate` to create a task for each phase so the user can track progress. Mark each task `in_progress` when you start it and `completed` when done.

Tasks to create:
1. Interview -- understand the job-to-be-done
2. Prototype -- build small scripts with SDK locally
3. Explore -- discover tools, skills, and gaps
4. Data model -- design state and storage
5. Agent definition -- write and test the agent

## Key distinction: Agent vs Skill

- **Agent** = a job-to-be-done. The main script that orchestrates a specific workflow end-to-end.
- **Skill** = a reusable capability. A function library any agent can call (e.g., `/product-analysis`).
- Compose skills inside agents for modularity and tight feedback loops.

## Prerequisites

Before starting, verify:
- `DATAGEN_API_KEY` is set (suggest `/datagen:setup` if not)
- DataGen MCP connection works (call `searchTools` with query "test")
- Python SDK is installed (`pip install datagen-python-sdk`) -- needed for Phase 2

If any prerequisite is missing, suggest `/datagen:setup` first.

---

## Phase 1: Interview the user

Understand the job-to-be-done through structured questions. Do NOT skip this phase -- it produces the context layer that makes the agent reliable.

**Ask these questions (use `AskUserQuestion` for each):**

1. **What task should the agent automate? What triggers it?**
   - Get the end-to-end workflow: input -> processing -> output
   - Understand the trigger: webhook, schedule, manual, or event-driven

2. **What does "good" output look like?**
   - Ask for an example, template, or screenshot of the ideal result
   - If the user has one, save it as `context/output-template.md`

3. **What rules or criteria drive decisions?**
   - Scoring rubrics, filtering logic, routing rules, thresholds
   - Save as `context/criteria.md`

4. **What domain knowledge is assumed?**
   - Glossaries, org context, edge cases, "watch out for" rules
   - Things a new team member would need to know
   - Save as `context/domain-context.md`

5. **What data sources does the agent read from? What does it write to?**
   - APIs, databases, files, spreadsheets, CRMs
   - This feeds into Phase 4 (data model)

**Organize the context layer:**

```bash
mkdir -p context
```

Create files based on answers:

| File | Content |
|------|---------|
| `context/output-template.md` | Example of ideal output |
| `context/criteria.md` | Decision rules, scoring, filtering logic |
| `context/domain-context.md` | Background knowledge, glossaries, edge cases |

The agent definition will reference these via `@context/` links. Context files separate domain knowledge from orchestration logic -- both are easier to maintain independently.

---

## Phase 2: Build small scripts with SDK locally

Do NOT write the full agent yet. Instead, prototype each step as a small standalone Python script using the DataGen SDK. This produces a working action trace of real tool calls with real data -- the ground truth for the agent definition.

**Important: Use the code-mode pattern (local scripts with `DatagenClient().execute_tool()`), NOT `executeCode`.**

For each step of the workflow identified in Phase 1:

### 2a. Write a small script

Create a script that calls one or two tools via the SDK:

```python
import os, json
from datagen_sdk import DatagenClient

client = DatagenClient()

# Example: scrape a company website
result = client.execute_tool("mcp_Firecrawl_firecrawl_scrape", {
    "url": "https://example.com"
})

# Save output for inspection
os.makedirs("tmp", exist_ok=True)
with open("tmp/scrape_result.json", "w") as f:
    json.dump(result, f, indent=2)

print("Saved to tmp/scrape_result.json")
```

### 2b. Save output to `tmp/`

Every script saves its output as JSON or CSV in `tmp/`. This follows the RLM pattern -- treat context as an external environment, use code to peek/grep/partition data.

```bash
mkdir -p tmp scripts
```

### 2c. Verify the output

After each script runs, read the output file and verify:
- Is the data structure what you expected?
- Are the fields populated correctly?
- Are there errors or missing data?

### 2d. Move to the next step

Once a script works, move to the next step of the workflow. Each script builds on the previous one's output.

**By the end of Phase 2, you should have:**
- A `scripts/` directory with one script per workflow step
- A `tmp/` directory with real output from each step
- A clear understanding of which tools work, what parameters they need, and what the output looks like

> This is the most important phase. Auto-generating agent definitions from a description produces hallucinated prompts. Prototyping first captures real tool names, real parameters, and real edge cases.

---

## Phase 3: Explore tools, skills, and resources

Before writing the agent definition, take inventory of what's available and what's missing.

### 3a. Discover existing tools

Use `searchTools` and `getToolDetails` MCP tools to find what DataGen tools are available for this job:

```
searchTools -> find tools by intent (e.g., "scrape website", "send email", "search LinkedIn")
getToolDetails -> confirm exact input schema for each tool
```

For each tool the agent needs:
1. Search for it by intent
2. Get its full schema
3. Note the exact alias name (e.g., `mcp_Gmail_gmail_send_email`)

### 3b. Check existing skills

Look in `.claude/skills/` for reusable capabilities that already exist:

```bash
ls -la .claude/skills/ 2>/dev/null
```

Can any existing skill handle part of this workflow?

### 3c. Identify gaps

After inventorying tools and skills, identify what's missing:
- **Missing tools**: Services that aren't connected to DataGen yet
- **Missing skills**: Reusable capabilities that should be extracted
- **Missing data**: Information that needs to be fetched from elsewhere

### 3d. Fill gaps

For each gap, suggest the appropriate action:

| Gap type | Action |
|----------|--------|
| MCP server not connected | Suggest `/datagen:add-mcps` to connect the service |
| Custom logic needed | Suggest `/datagen:create-custom-tool` to build it |
| External API needed | Search online for MCP servers or APIs that provide it |
| Reusable capability | Create a new skill in `.claude/skills/` |

Use `WebSearch` to find MCP servers, APIs, or approaches that fill gaps.

---

## Phase 4: Create state / data model

Design the stateful data model the agent needs for ongoing operation. This step is critical for agents that track entities over time (enrichment pipelines, monitoring, reporting).

### 4a. Map entities

What objects does the agent track?
- Contacts, companies, posts, leads, campaigns, etc.
- What fields does each entity have?

### 4b. Define lifecycle

What states does each entity go through?

```
Example: Contact enrichment pipeline
  pending -> scraped -> enriched -> scored -> exported
```

### 4c. Identify dedup keys

How to identify duplicates?
- Domain name for companies
- Email for contacts
- URL for web pages

### 4d. Choose storage

Where does state live?

| Storage type | When to use |
|-------------|-------------|
| JSON files in `tmp/` | Short-lived, single-run pipelines |
| Markdown docs in `context/` | Agent memory and heuristics |
| CSV files | Tabular data, CRM imports/exports |
| Database (via MCP) | Long-lived state, multi-run tracking |
| Google Sheets (via MCP) | Collaborative data, user-facing dashboards |

### 4e. Define read-before-act / write-after-act

For each step in the workflow:
- **Read**: What does the agent read to decide what to do?
- **Act**: What action does it take?
- **Write**: What does it write after acting?

### 4f. Save the data model

Save as `context/data-model.md`:

```markdown
# Data Model

## Entities
- **Company**: domain, name, industry, size, score
  - Lifecycle: pending -> scraped -> enriched -> scored -> exported
  - Dedup key: domain

## Storage
- `tmp/companies.json` -- working state during a run
- `context/icp-criteria.md` -- scoring rules (agent memory)

## Step data flow
| Step | Reads | Writes |
|------|-------|--------|
| 1. Parse input | input CSV | tmp/companies.json |
| 2. Scrape | tmp/companies.json | tmp/scrape_{domain}.json |
| ... | ... | ... |
```

---

## Phase 5: Plan and execute

Write the agent definition based on everything gathered in Phases 1-4.

### 5a. Look up the current agent file format

Before writing the agent `.md` file, verify the current required format. Use the `claude-code-guide` subagent:

```
Task(subagent_type="claude-code-guide", prompt="Research the correct format for Claude Code custom agents defined in .claude/agents/ directory. What frontmatter fields are required/supported? What is the naming convention?")
```

### 5b. Create the agent definition

Create `.claude/agents/<agent-name>.md` with proper YAML frontmatter:

```markdown
---
name: <agent-name>
description: <what the agent does>
---

# <Agent Name>

## Context
Follow the format in @context/output-template.md.
Apply rules from @context/criteria.md.
Use the data model in @context/data-model.md.
Watch for issues in @context/domain-context.md.

## Steps

### Step 1: <step name>
1. <what to do>
2. Run: `python3 scripts/<script>.py --arg value`
3. Verify: check tmp/<output>.json exists and is valid
4. Error handling: <what to do if it fails>

### Step 2: <step name>
...
```

### 5c. Structure as numbered steps

Each step should reference the scripts from Phase 2:
- **What to run**: The script or tool call
- **What to check**: Expected output file and format
- **When to skip**: Conditions where the step is unnecessary
- **Error handling**: What to do on failure (retry, skip, fallback)

### 5d. Add learnings file

Create `learnings/common_failures_and_fix.md` for accumulated knowledge:

```bash
mkdir -p learnings
```

```markdown
# Common Failures and Fixes

## Known issues
- <failure pattern> -> <fix>

## Edge cases
- <edge case> -> <handling>

## Performance notes
- <observation> -> <optimization>
```

The agent references this to avoid repeating mistakes: `@learnings/common_failures_and_fix.md`

### 5e. Test the agent

> **Important:** If you just created or modified an agent `.md` file, you must restart Claude Code before the agent will be discoverable. Agents are loaded at session start.

1. Exit Claude Code and restart with `claude -r` to resume with the new agent loaded
2. Run the agent on the target task
3. Observe: Does it follow steps in order? Handle errors? Produce expected output?
4. Iterate: refine the agent definition based on results

### 5f. When ready to deploy

Point the user to `/datagen:deploy-agent` for:
- Pushing to GitHub
- Connecting the repo to DataGen
- Deploying as webhook or scheduled automation
- Configuring secrets and triggers

---

## Architecture principles (summary)

1. **Develop by doing, not by prompting** -- Phase 2 (prototyping) is the most important phase
2. **Context is the enemy (RLM pattern)** -- use script-based outputs in `tmp/`, not inline reasoning
3. **Make the model plan before it acts** -- task list with dependency graph upfront
4. **Validate with hooks, not hope** -- define expected output schemas per step
5. **The real product is encoded expertise** -- context files are the differentiator
6. **Compose skills inside agents** -- break complex capabilities into reusable skills

## Next steps

After the agent is built and tested, suggest:
- `/datagen:deploy-agent` to deploy your agent as a webhook or scheduled automation

## Error handling

- If SDK is not installed: suggest `pip install datagen-python-sdk` or `/datagen:setup`
- If tools are not found: verify MCP connection, suggest `/datagen:add-mcps`
- If scripts fail: check tool schemas with `getToolDetails`, verify parameters
- If agent doesn't load after creation: remind user to restart Claude Code (`claude -r`)
