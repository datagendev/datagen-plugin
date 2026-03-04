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
1. Interview -- understand intent, data model, context sources, and feedback loop
2. Context & Memory -- write context files and memory markdown from interview
3. Data model -- design DB schemas and in-run data flow
4. Explore & create skills -- check existing skills, discover tools, create new skills for reusable capabilities
5. Prototype -- build helper scripts with SDK locally
6. Agent definition -- write and test the agent

## Critical principle: Agent is the brain, scripts are the hands

**The agent `.md` file is the orchestrator.** It reasons, decides, and coordinates. Scripts are helper tools the agent calls to handle specific heavy-lifting tasks (large data processing, long-running API calls, batch operations).

Do NOT write one end-to-end script that replaces the agent. That defeats the purpose -- you lose the agent's ability to reason between steps, adapt to errors, and make decisions based on intermediate results.

**Right approach:**
- Agent reads input, decides what to do
- Agent calls `.datagen/agent/<agent-name>/scripts/scrape.py` to handle bulk scraping
- Agent reviews the output, decides next action
- Agent calls `.datagen/agent/<agent-name>/scripts/enrich.py` to process results
- Agent evaluates, writes summary, handles edge cases

**Wrong approach:**
- One `run_everything.py` that does scrape -> enrich -> score -> export with no agent reasoning in between

Scripts handle what code does best (data wrangling, API calls, file I/O). The agent handles what LLMs do best (reasoning, judgment, adaptation, decision-making).

## Key distinction: Agent vs Skill

- **Agent** = a job-to-be-done. The orchestrator that reasons through a specific workflow end-to-end.
- **Skill** = a reusable capability. A function library any agent can call (e.g., `/product-analysis`). Lives in `.claude/skills/`.
- Compose skills inside agents for modularity and tight feedback loops.

## Prerequisites

Before starting, verify:
- `DATAGEN_API_KEY` is set (suggest `/datagen:setup` if not)
- DataGen MCP connection works (call `searchTools` with query "test")
- Python SDK is installed (`pip install datagen-python-sdk`) -- needed for Phase 5

If any prerequisite is missing, suggest `/datagen:setup` first.

## Agent directory layout

All agent workspace files live under `.datagen/agent/<agent-name>/`. Determine the agent name during the interview (Phase 1) and create this structure:

```
.datagen/agent/<agent-name>/
├── context/                    # domain knowledge, criteria, templates (Phase 2)
├── memory/
│   ├── STATE.md                # [all tiers] aggregate state (last run, counters)
│   ├── preferences.md          # [all tiers] user rules and preferences
│   ├── JOURNAL/                # [all tiers] append-only session logs
│   ├── PROFILE.md              # [tier 2+] agent identity, sync direction, dedup strategy
│   ├── PIPELINE.md             # [tier 2+] workflow stage tracking
│   ├── DECISIONS.md            # [tier 2+] decision audit trail
│   ├── feedback_learnings.md   # [tier 2+] skip patterns, quality signals
│   ├── entities/               # [tier 2+] per-entity state files
│   └── EVENTS.log              # [tier 2+] append-only event log
├── tmp/                        # ephemeral in-run data, discarded between runs (Phase 5)
├── scripts/                    # helper scripts the agent calls (Phase 5)
├── learnings/                  # accumulated failure patterns and fixes (Phase 6)
└── data/                       # local DB files if using SQLite (Phase 3)
```

The agent definition itself lives at `.claude/agents/<agent-name>.md` and references workspace files via `@.datagen/agent/<agent-name>/context/...` etc.

Skills live separately in `.claude/skills/<skill-name>/` -- they are reusable across agents.

---

## Phases

Each phase has its own detailed guide. Read and follow the linked file when you reach that phase.

### Phase 1: Interview the user
> Detailed guide: @phases/01-interview.md

Understand the job through four focused conversations: intent, data model, context sources, and feedback loop. Produces the agent blueprint.

**Key outputs:** Agent blueprint (approved by user), directory structure created.

**Checkpoint:** Present the full blueprint. Do NOT proceed until approved.

---

### Phase 2: Context & Memory preparation
> Detailed guide: @phases/02-context-memory.md

Turn interview answers into actual files the agent will read. Draft each file, present to the user, iterate until approved.

**Key outputs:** `context/` files (goal, criteria, output template, domain context) and tier-appropriate `memory/` files (STATE, preferences, JOURNAL for all tiers; PROFILE, PIPELINE, DECISIONS, entities, EVENTS for tier 2+).

**Checkpoint:** List all created files. Do NOT proceed until approved.

---

### Phase 3: Data model
> Detailed guide: @phases/03-data-model.md

Design DB schemas (if needed) and map ephemeral in-run data flow. Decide what needs a database vs `tmp/` files.

**Key outputs:** `context/data-model.md`, SQL migration script (if using DB), ephemeral flow table.

**Checkpoint:** Present the data model. Do NOT proceed until approved.

---

### Phase 4: Explore tools and create skills
> Detailed guide: @phases/04-explore-skills.md

Take inventory of available skills and tools. **Prioritize creating skills** for reusable capabilities (in `.claude/skills/`). Plan agent-specific data prep scripts (in `.datagen/agent/<agent-name>/scripts/`).

**Key outputs:** New skills created in `.claude/skills/`, data prep script plan, tool inventory.

**Checkpoint:** Present the full tooling plan (skills, scripts, tools, gaps). Do NOT proceed until approved.

---

### Phase 5: Prototype with small helper scripts
> Detailed guide: @phases/05-prototype.md

Build the helper scripts the agent will call. Each script handles one specific task. Use the code-mode pattern with `DatagenClient().execute_tool()`.

**Key outputs:** Working scripts in `.datagen/agent/<agent-name>/scripts/`, verified output in `tmp/`.

---

### Phase 6: Write the agent definition
> Detailed guide: @phases/06-agent-definition.md

Write the agent `.md` file that orchestrates everything. The agent reasons between steps, calls skills and scripts, and adapts to results.

**Key outputs:** `.claude/agents/<agent-name>.md`, `learnings/common_failures_and_fix.md`, tested agent.

---

## Architecture principles (summary)

1. **Agent is the brain, scripts are the hands** -- never replace agent reasoning with an end-to-end script
2. **Develop by doing, not by prompting** -- Phase 5 (prototyping) captures real tool behavior
3. **Context is the enemy (RLM pattern)** -- use script-based outputs in `.datagen/agent/<agent-name>/tmp/`, not inline reasoning
4. **Make the model plan before it acts** -- task list with dependency graph upfront
5. **Validate with hooks, not hope** -- define expected output schemas per step
6. **The real product is encoded expertise** -- context files are the differentiator
7. **Compose skills inside agents** -- break complex capabilities into reusable skills in `.claude/skills/`
8. **Memory is a first-class concern** -- classify the agent's memory tier (simple, structured, event-sourced) during the interview. The tier determines directory structure, file templates, hook scripts, and agent loading patterns. Ephemeral state lives in `tmp/`, persistent state lives in `memory/` (L1) and DB (L2). All under `.datagen/agent/<agent-name>/`

## Next steps

After the agent is built and tested, suggest:
- `/datagen:deploy-agent` to deploy your agent as a webhook or scheduled automation

## Error handling

- If SDK is not installed: suggest `pip install datagen-python-sdk` or `/datagen:setup`
- If tools are not found: verify MCP connection, suggest `/datagen:add-mcps`
- If scripts fail: check tool schemas with `getToolDetails`, verify parameters
- If agent doesn't load after creation: remind user to restart Claude Code (`claude -r`)
