---
name: build-agent
description: Walk through building a new DataGen agent from scratch -- interview, explore, model data, prototype, and write the agent definition
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
2. Explore -- discover tools, skills, and gaps
3. Data model -- design how data flows and is arranged
4. Prototype -- build small helper scripts with SDK locally
5. Agent definition -- write and test the agent

## Critical principle: Agent is the brain, scripts are the hands

**The agent `.md` file is the orchestrator.** It reasons, decides, and coordinates. Scripts are helper tools the agent calls to handle specific heavy-lifting tasks (large data processing, long-running API calls, batch operations).

Do NOT write one end-to-end script that replaces the agent. That defeats the purpose -- you lose the agent's ability to reason between steps, adapt to errors, and make decisions based on intermediate results.

**Right approach:**
- Agent reads input, decides what to do
- Agent calls `scripts/scrape.py` to handle bulk scraping
- Agent reviews the output, decides next action
- Agent calls `scripts/enrich.py` to process results
- Agent evaluates, writes summary, handles edge cases

**Wrong approach:**
- One `scripts/run_everything.py` that does scrape -> enrich -> score -> export with no agent reasoning in between

Scripts handle what code does best (data wrangling, API calls, file I/O). The agent handles what LLMs do best (reasoning, judgment, adaptation, decision-making).

## Key distinction: Agent vs Skill

- **Agent** = a job-to-be-done. The orchestrator that reasons through a specific workflow end-to-end.
- **Skill** = a reusable capability. A function library any agent can call (e.g., `/product-analysis`).
- Compose skills inside agents for modularity and tight feedback loops.

## Prerequisites

Before starting, verify:
- `DATAGEN_API_KEY` is set (suggest `/datagen:setup` if not)
- DataGen MCP connection works (call `searchTools` with query "test")
- Python SDK is installed (`pip install datagen-python-sdk`) -- needed for Phase 4

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
   - This feeds into Phase 3 (data model)

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

## Phase 2: Explore tools, skills, and resources

Before prototyping, take inventory of what's available and what's missing. This informs what scripts you need to build and how the agent will orchestrate them.

### 2a. Discover existing tools

Use `searchTools` and `getToolDetails` MCP tools to find what DataGen tools are available for this job:

```
searchTools -> find tools by intent (e.g., "scrape website", "send email", "search LinkedIn")
getToolDetails -> confirm exact input schema for each tool
```

For each tool the agent needs:
1. Search for it by intent
2. Get its full schema
3. Note the exact alias name (e.g., `mcp_Gmail_gmail_send_email`)

### 2b. Check existing skills

Look in `.claude/skills/` for reusable capabilities that already exist:

```bash
ls -la .claude/skills/ 2>/dev/null
```

Can any existing skill handle part of this workflow?

### 2c. Identify gaps

After inventorying tools and skills, identify what's missing:
- **Missing tools**: Services that aren't connected to DataGen yet
- **Missing skills**: Reusable capabilities that should be extracted
- **Missing data**: Information that needs to be fetched from elsewhere

### 2d. Fill gaps

For each gap, suggest the appropriate action:

| Gap type | Action |
|----------|--------|
| MCP server not connected | Suggest `/datagen:add-mcps` to connect the service |
| Custom logic needed | Suggest `/datagen:create-custom-tool` to build it |
| External API needed | Search online for MCP servers or APIs that provide it |
| Reusable capability | Create a new skill in `.claude/skills/` |

Use `WebSearch` to find MCP servers, APIs, or approaches that fill gaps.

---

## Phase 3: Design the data model

This is not just about storage format -- it's about how the agent arranges and flows data between steps. Interview the user about how they think about the data, not just what fields exist.

### 3a. Interview: How does the user think about this data?

**Ask these questions (use `AskUserQuestion`):**

1. **How do you organize this data today?** (spreadsheet columns, CRM fields, mental model)
2. **What's the natural grouping?** (by company, by person, by deal, by time period)
3. **What order do things happen in?** (what gets done first, what depends on what)
4. **What does "done" look like for each item?** (statuses, stages, lifecycle)

This conversation shapes the data model more than any technical analysis.

### 3b. Map entities

What objects does the agent track?
- Contacts, companies, posts, leads, campaigns, etc.
- What fields does each entity have?

### 3c. Define lifecycle

What states does each entity go through?

```
Example: Contact enrichment pipeline
  pending -> scraped -> enriched -> scored -> exported
```

### 3d. Identify dedup keys

How to identify duplicates?
- Domain name for companies
- Email for contacts
- URL for web pages

### 3e. Choose storage

Where does state live?

| Storage type | When to use |
|-------------|-------------|
| JSON files in `tmp/` | Short-lived, single-run pipelines |
| Markdown docs in `context/` | Agent memory and heuristics |
| CSV files | Tabular data, CRM imports/exports |
| Database (via MCP) | Long-lived state, multi-run tracking |
| Google Sheets (via MCP) | Collaborative data, user-facing dashboards |

### 3f. Define the data flow between agent steps

For each step in the workflow, map what the **agent** reads and decides vs what a **script** handles:

| Step | Agent decides | Script handles | Output |
|------|--------------|----------------|--------|
| 1. Parse input | What format is this? Which fields matter? | Parse CSV/JSON, normalize | `tmp/parsed.json` |
| 2. Enrich | Which records need enrichment? Skip duplicates? | Batch API calls, rate limiting | `tmp/enriched.json` |
| 3. Score | Apply criteria from `context/criteria.md` | Number crunching on large datasets | `tmp/scored.json` |
| 4. Decide | Which records pass? What action for each? | -- (agent's job) | -- |
| 5. Output | Format selection, error summary | Write to CRM, send emails | `tmp/export_log.json` |

This table is the blueprint for the agent definition. The "Agent decides" column becomes agent steps. The "Script handles" column becomes helper scripts.

### 3g. Save the data model

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

## Agent-script data flow
| Step | Agent decides | Script handles | Output |
|------|--------------|----------------|--------|
| 1. Parse input | format, relevant fields | parsing, normalization | tmp/parsed.json |
| 2. Scrape | which domains to scrape | bulk HTTP requests | tmp/scraped.json |
| ... | ... | ... | ... |
```

---

## Phase 4: Prototype with small helper scripts

Now build the helper scripts the agent will call. Each script handles one specific task -- the agent orchestrates them.

**Important: Use the code-mode pattern (local scripts with `DatagenClient().execute_tool()`), NOT `executeCode`.**

**Remember: Each script is a tool for the agent, not a replacement for it.** Keep scripts focused on data processing, API calls, and I/O. The agent handles reasoning, decisions, and coordination between scripts.

### 4a. Write one script per "Script handles" column from Phase 3

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

### 4b. Save output to `tmp/`

Every script saves its output as JSON or CSV in `tmp/`. This follows the RLM pattern -- treat context as an external environment, use code to peek/grep/partition data.

```bash
mkdir -p tmp scripts
```

### 4c. Verify the output

After each script runs, read the output file and verify:
- Is the data structure what you expected?
- Are the fields populated correctly?
- Are there errors or missing data?

### 4d. Move to the next step

Once a script works, move to the next step of the workflow. Each script builds on the previous one's output.

**By the end of Phase 4, you should have:**
- A `scripts/` directory with one script per heavy-lifting task
- A `tmp/` directory with real output from each step
- A clear understanding of which tools work, what parameters they need, and what the output looks like
- A clear separation: scripts do data work, agent does thinking work

> Prototyping captures real tool names, real parameters, and real edge cases. But remember -- these scripts are helpers the agent calls, not an end-to-end pipeline.

---

## Phase 5: Write the agent definition

Write the agent definition based on everything gathered in Phases 1-4. The agent is the orchestrator -- it reasons between steps, makes decisions, and calls scripts when it needs heavy lifting done.

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

### Step 1: <understand input>
1. Read the input and determine format, scope, and any issues
2. Run: `python3 scripts/parse_input.py --file <input>`
3. Review output in tmp/parsed.json
4. Decide: are there records to skip? duplicates? bad data?

### Step 2: <process data>
1. Based on parsed results, decide which records need processing
2. Run: `python3 scripts/enrich.py`
3. Review output in tmp/enriched.json
4. Evaluate: did enrichment succeed? any failures to retry?

### Step 3: <apply judgment>
1. Read criteria from @context/criteria.md
2. For each record, apply scoring/filtering logic
3. Run: `python3 scripts/score.py` (if dataset is large)
4. Review scores and decide which records qualify

### Step 4: <take action>
1. Based on decisions above, determine the right action for each record
2. Run: `python3 scripts/export.py --target <destination>`
3. Verify results and write summary
```

### 5c. Ensure the agent reasons between steps

Each step in the agent definition should have:
- **A decision point**: What does the agent evaluate before proceeding?
- **A script call** (if needed): What heavy lifting does a script handle?
- **A review moment**: Agent checks the output and adapts
- **Error handling**: What to do on failure (retry, skip, fallback)

The agent should NEVER just run scripts back-to-back without reasoning. If a step has no decision point, ask: should this be merged into the previous step's script instead?

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
3. Observe: Does it reason between steps? Does it adapt when something fails? Does it make good decisions?
4. Iterate: refine the agent definition based on results

### 5f. When ready to deploy

Point the user to `/datagen:deploy-agent` for:
- Pushing to GitHub
- Connecting the repo to DataGen
- Deploying as webhook or scheduled automation
- Configuring secrets and triggers

---

## Architecture principles (summary)

1. **Agent is the brain, scripts are the hands** -- never replace agent reasoning with an end-to-end script
2. **Develop by doing, not by prompting** -- Phase 4 (prototyping) captures real tool behavior
3. **Context is the enemy (RLM pattern)** -- use script-based outputs in `tmp/`, not inline reasoning
4. **Make the model plan before it acts** -- task list with dependency graph upfront
5. **Validate with hooks, not hope** -- define expected output schemas per step
6. **The real product is encoded expertise** -- context files are the differentiator
7. **Compose skills inside agents** -- break complex capabilities into reusable skills

## Next steps

After the agent is built and tested, suggest:
- `/datagen:deploy-agent` to deploy your agent as a webhook or scheduled automation

## Error handling

- If SDK is not installed: suggest `pip install datagen-python-sdk` or `/datagen:setup`
- If tools are not found: verify MCP connection, suggest `/datagen:add-mcps`
- If scripts fail: check tool schemas with `getToolDetails`, verify parameters
- If agent doesn't load after creation: remind user to restart Claude Code (`claude -r`)
