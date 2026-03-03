# Phase 6: Write the agent definition

Write the agent definition based on everything gathered in Phases 1-5. The agent is the orchestrator -- it reasons between steps, makes decisions, and calls scripts when it needs heavy lifting done.

## 6a. Look up the current agent file format

Before writing the agent `.md` file, verify the current required format. Use the `claude-code-guide` subagent:

```
Task(subagent_type="claude-code-guide", prompt="Research the correct format for Claude Code custom agents defined in .claude/agents/ directory. What frontmatter fields are required/supported? What is the naming convention?")
```

## 6b. Create the agent definition

Create `.claude/agents/<agent-name>.md` with proper YAML frontmatter:

```markdown
---
name: <agent-name>
description: <what the agent does>
---

# <Agent Name>

## Context
Follow the format in @.datagen/agent/<agent-name>/context/output-template.md.
Apply rules from @.datagen/agent/<agent-name>/context/criteria.md.
Use the data model in @.datagen/agent/<agent-name>/context/data-model.md.
Watch for issues in @.datagen/agent/<agent-name>/context/domain-context.md.

## Memory
Load cross-run state from @.datagen/agent/<agent-name>/memory/*.md.
Check user preferences in @.datagen/agent/<agent-name>/memory/preferences.md before making decisions.
Check feedback learnings in @.datagen/agent/<agent-name>/memory/feedback_learnings.md before filtering steps.

## Steps

### Step 1: <understand input>
1. Read the input and determine format, scope, and any issues
2. Run: `python3 .datagen/agent/<agent-name>/scripts/parse_input.py --file <input>`
3. Review output in .datagen/agent/<agent-name>/tmp/parsed.json
4. Decide: are there records to skip? duplicates? bad data?

### Step 2: <process data>
1. Based on parsed results, decide which records need processing
2. Run: `python3 .datagen/agent/<agent-name>/scripts/enrich.py`
3. Review output in .datagen/agent/<agent-name>/tmp/enriched.json
4. Evaluate: did enrichment succeed? any failures to retry?

### Step 3: <apply judgment>
1. Read criteria from @.datagen/agent/<agent-name>/context/criteria.md
2. For each record, apply scoring/filtering logic
3. Run: `python3 .datagen/agent/<agent-name>/scripts/score.py` (if dataset is large)
4. Review scores and decide which records qualify

### Step 4: <take action>
1. Based on decisions above, determine the right action for each record
2. Run: `python3 .datagen/agent/<agent-name>/scripts/export.py --target <destination>`
3. Verify results and write summary

### Step N: <write memory>
1. Ask: "Any corrections or preferences to note?"
2. If feedback provided, run: `python3 .datagen/agent/<agent-name>/scripts/apply_feedback.py`
3. Run: `python3 .datagen/agent/<agent-name>/scripts/write_memory.py` to update L1 (and L2 if configured)
4. Verify memory files were updated
```

## 6c. Ensure the agent reasons between steps

Each step in the agent definition should have:
- **A decision point**: What does the agent evaluate before proceeding?
- **A script call** (if needed): What heavy lifting does a script handle?
- **A review moment**: Agent checks the output and adapts
- **Error handling**: What to do on failure (retry, skip, fallback)

The agent should NEVER just run scripts back-to-back without reasoning. If a step has no decision point, ask: should this be merged into the previous step's script instead?

## 6d. Add learnings file

Create `.datagen/agent/<agent-name>/learnings/common_failures_and_fix.md` for accumulated knowledge:

```bash
mkdir -p .datagen/agent/<agent-name>/learnings
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

The agent references this to avoid repeating mistakes: `@.datagen/agent/<agent-name>/learnings/common_failures_and_fix.md`

## 6e. Test the agent

> **Important:** If you just created or modified an agent `.md` file, you must restart Claude Code before the agent will be discoverable. Agents are loaded at session start.

1. Exit Claude Code and restart with `claude -r` to resume with the new agent loaded
2. Run the agent on the target task
3. Observe: Does it reason between steps? Does it adapt when something fails? Does it make good decisions?
4. Iterate: refine the agent definition based on results

## 6f. When ready to deploy

Point the user to `/datagen:deploy-agent` for:
- Pushing to GitHub
- Connecting the repo to DataGen
- Deploying as webhook or scheduled automation
- Configuring secrets and triggers
