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

## Memory (tier-specific -- use only the block matching this agent's tier)

<!-- Tier 1: Simple -->
Load state from @.datagen/agent/<agent-name>/memory/STATE.md at the start of each run.
Check user preferences in @.datagen/agent/<agent-name>/memory/preferences.md before making decisions.

<!-- Tier 2: Structured -->
Load agent profile from @.datagen/agent/<agent-name>/memory/PROFILE.md.
Load state from @.datagen/agent/<agent-name>/memory/STATE.md.
Load pipeline state from @.datagen/agent/<agent-name>/memory/PIPELINE.md.
Check user preferences in @.datagen/agent/<agent-name>/memory/preferences.md before making decisions.
Check feedback learnings in @.datagen/agent/<agent-name>/memory/feedback_learnings.md before filtering steps.
Load entity files from @.datagen/agent/<agent-name>/memory/entities/ on demand (don't load all at once).

<!-- Tier 3: Event-sourced (same as Tier 2, plus:) -->
Check idempotency state: read last key from @.datagen/agent/<agent-name>/memory/EVENTS.log before processing.

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

### Step N: <write memory> (tier-specific -- use matching block)

<!-- Tier 1: Simple -->
1. Ask: "Any corrections or preferences to note?"
2. Update @.datagen/agent/<agent-name>/memory/STATE.md with run counters and outcome
3. Append session log to @.datagen/agent/<agent-name>/memory/JOURNAL/

<!-- Tier 2: Structured -->
1. Ask: "Any corrections or preferences to note?"
2. If feedback provided, run: `python3 .datagen/agent/<agent-name>/scripts/apply_feedback.py`
3. Update @.datagen/agent/<agent-name>/memory/STATE.md with run counters and outcome
4. Update @.datagen/agent/<agent-name>/memory/PIPELINE.md with current stage positions
5. Update entity files in @.datagen/agent/<agent-name>/memory/entities/ for changed entities
6. Append events to @.datagen/agent/<agent-name>/memory/EVENTS.log
7. Append session log to @.datagen/agent/<agent-name>/memory/JOURNAL/
8. Check if rollup threshold reached (if configured in PROFILE.md)

<!-- Tier 3: Event-sourced (same as Tier 2, plus:) -->
9. Verify idempotency: check all events have unique keys before appending
10. Run mandatory rollup if threshold met
```

## 6b2. Configure memory hooks in `.claude/settings.json`

Wire the memory lifecycle scripts (from Phase 5) to Claude Code events via `.claude/settings.json`. This is the default approach -- hooks are always active and work across all sessions.

**Hook mapping by tier:**

| Memory hook | Claude Code event | Script |
|-------------|------------------|--------|
| **recall** | `SessionStart` | `python3 .datagen/agent/<agent-name>/scripts/memory_recall.py` |
| **flush** | `Stop` | `python3 .datagen/agent/<agent-name>/scripts/memory_flush.py` |
| **lock** (T2+) | `PreToolUse` matcher `Edit\|Write` | Advisory warning if target is in `memory/entities/` |
| **event log** (T2+) | `PostToolUse` matcher on relevant tools | Appends to `EVENTS.log` |
| **rollup** (T3) | `Stop` | Checks run count, summarizes if threshold met |

**Tier 1 settings.json hooks:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "python3 .datagen/agent/<agent-name>/scripts/memory_recall.py" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "python3 .datagen/agent/<agent-name>/scripts/memory_flush.py" }
        ]
      }
    ]
  }
}
```

**Tier 2+ additions** (merge into the same settings.json):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "python3 .datagen/agent/<agent-name>/scripts/memory_recall.py" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "python3 .datagen/agent/<agent-name>/scripts/memory_flush.py" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "python3 .datagen/agent/<agent-name>/scripts/memory_lock_check.py \"$TOOL_INPUT\"" }
        ]
      }
    ]
  }
}
```

Add these hooks to the project-level `.claude/settings.json` so they apply to all sessions in this project. The scripts themselves are tier-specific (built in Phase 5).

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
