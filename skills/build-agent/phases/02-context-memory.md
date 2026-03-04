# Phase 2: Context & Memory preparation

Turn interview answers into actual files the agent will read. This is the tangible output of Phase 1 -- don't skip it. Each file should be drafted, presented to the user for review, and only saved after approval.

## 2a. Write context files

Draft the following files from interview answers. Present each to the user before saving. All paths are relative to `.datagen/agent/<agent-name>/`.

| File | Source | Content |
|------|--------|---------|
| `context/output-template.md` | 1a (ideal output) | Example or template of what good output looks like |
| `context/criteria.md` | 1a (rules, judgment) | Decision rules, scoring rubrics, filtering logic |
| `context/domain-context.md` | 1c (domain knowledge) | Background knowledge, glossaries, edge cases, industry terms |

For each file:
1. Draft the content based on what the user said in the interview
2. Present it to the user: "Here's what I drafted for `context/criteria.md` -- does this capture your rules correctly?"
3. Iterate until approved, then save to `.datagen/agent/<agent-name>/context/`

If the user provided reference lists or lookup tables (from 1c), save each as its own file in `.datagen/agent/<agent-name>/context/` (e.g., `context/target-accounts.md`, `context/icp-definition.md`).

## 2b. Write memory files (tier-specific)

Create memory files based on the tier classified in Phase 1 (1d2). Each tier builds on the previous one.

---

### 2b-T1. Tier 1 -- Simple (state container)

For: to-do agents, single-entity trackers, linear batch processors, daily report generators.

**Files:**

**`memory/STATE.md`** -- aggregate state the agent reads at the start of each run and updates at the end:

```markdown
# State

## Last run
- Date: <not yet run>
- Items processed: 0
- Outcome: --

## Counters
- Total items: 0
- Completed: 0
- Pending: 0
```

**`memory/preferences.md`** -- from 1c answers (user rules, filters, output format):

```markdown
# Preferences

## Filters
- <filter rules from interview>

## Scoring weights
- <weights from interview>

## Output format
- <format preferences from interview>
```

**`memory/JOURNAL/`** -- append-only session logs. Each run creates `YYYY-MM-DD_HHMMSS.md`:

```markdown
# Session: 2026-03-04 14:30:00

## Actions taken
- <what the agent did>

## Decisions made
- <key judgment calls>

## Notes
- <anything unusual or worth remembering>
```

**Example: to-do agent using Tier 1 memory.**
A simple to-do agent tracks tasks for the user. Here's how it uses memory across runs:

- `STATE.md` stores `Total items: 12, Completed: 8, Pending: 4` -- the agent reads this at session start so it knows where things stand without re-scanning the full list.
- `preferences.md` stores `Default priority: medium`, `Sort by: due date`, `Remind me about items older than 3 days` -- the agent applies these rules when showing tasks or deciding what to surface.
- `JOURNAL/2026-03-04_143000.md` logs "Added 3 tasks, completed 2, moved 1 to waiting" -- the user (or a future rollup) can review what happened each session.

On the next run, the agent reads `STATE.md` + `preferences.md`, picks up where it left off, and appends a new journal entry. No entity files, no event log -- just state, prefs, and a log.

**Hooks (conceptual):**
- **recall** (SessionStart): read `STATE.md` + `preferences.md`, print summary to stdout
- **flush** (Stop): update `STATE.md` counters, append new `JOURNAL/` entry

---

### 2b-T2. Tier 2 -- Structured (coordination layer)

For: CRM pipelines, multi-entity agents, agents syncing with external systems.

Includes all Tier 1 files, plus:

**`memory/PROFILE.md`** -- agent identity and coordination rules:

```markdown
# Agent Profile

## Identity
- Name: <agent-name>
- Memory tier: 2
- Created: <date>

## Sync direction
- Source of truth: <CRM / local / bidirectional>
- Dedup strategy: <field-based / fuzzy match / external ID>

## Thresholds
- Max entities in working memory: <number>
- Rollup frequency: <every N runs, or "manual">
```

**`memory/PIPELINE.md`** -- workflow stage tracking:

```markdown
# Pipeline State

## Active stages
| Entity ID | Type | Stage | Entered | Blocked by |
|-----------|------|-------|---------|------------|

## Stage definitions
- <stage name>: <what it means, exit criteria>
```

**`memory/DECISIONS.md`** -- decision audit trail:

```markdown
# Decision Log

<!-- Append new decisions at the top -->
| Date | Entity | Decision | Rationale | Outcome |
|------|--------|----------|-----------|---------|
```

**`memory/feedback_learnings.md`** -- from 1d answers (feedback loop design):

```markdown
# Feedback Learnings

## Skip patterns
<!-- Patterns learned from user feedback. The agent reads this before filtering steps. -->

## Quality signals
<!-- Positive patterns that indicate good results -->
```

If the user said they want auto-learn (from 1d), note that in the file header. If review-first, add a comment reminding the agent to propose changes before writing.

**`memory/entities/`** -- per-entity state files. Each entity gets `<type>_<id>.md`:

```markdown
# <Entity Type>: <Entity ID>

## Current state
- Stage: <pipeline stage>
- Last updated: <timestamp>

## History
- <date>: <what changed>
```

**`memory/EVENTS.log`** -- append-only event log:

```
[2026-03-04T14:30:00Z] [STAGE_CHANGE] contact_123: new -> enriched
[2026-03-04T14:30:05Z] [DECISION] contact_123: scored 0.85, qualified
[2026-03-04T14:31:00Z] [EXPORT] contact_123: pushed to CRM
```

**Hooks (conceptual):**
- **recall** (SessionStart): read `PROFILE.md`, `STATE.md`, `PIPELINE.md`, `preferences.md`, `feedback_learnings.md`; lazy-load entity files on demand
- **flush** (Stop): update `STATE.md` + `PIPELINE.md` + entity files, append `EVENTS.log` + `JOURNAL/`
- **lock** (advisory): warn if concurrent access detected on `memory/entities/` files
- **rollup** (optional): every N runs, summarize `EVENTS.log` and archive old journal entries

---

### 2b-T3. Tier 3 -- Event-sourced (high-concurrency)

Same structure as Tier 2, with additions. Mark as advanced -- uncommon for local Claude Code agents.

**`PROFILE.md` additions:**

```markdown
## Concurrency
- Idempotency key format: <agent-name>_<run-id>_<step>_<entity-id>
- Conflict resolution: <last-write-wins / manual-review / merge>
- Max parallel updates: <number>
```

**`EVENTS.log` entries include idempotency key:**

```
[2026-03-04T14:30:00Z] [STAGE_CHANGE] contact_123: new -> enriched | idem:agent_run42_enrich_123
```

**`DECISIONS.md` additions:**

```markdown
## Conflicts
| Date | Entity | Conflict type | Resolution | Key |
|------|--------|--------------|------------|-----|
```

**Rollup is mandatory** -- define frequency in `PROFILE.md`. The rollup script summarizes `EVENTS.log`, archives resolved entity files, and resets counters in `STATE.md`.

---

### 2b-hooks. Memory hook summary

These are conceptual patterns that Phase 5 implements as scripts and Phase 6 wires into `.claude/settings.json`.

| Hook | Trigger | Tier 1 | Tier 2 | Tier 3 |
|------|---------|--------|--------|--------|
| **recall** | SessionStart | Read STATE + prefs | + PROFILE, PIPELINE, learnings; lazy-load entities | Same as T2 + check idempotency state |
| **flush** | Stop | Update STATE, append JOURNAL | + update PIPELINE + entities, append EVENTS | Same as T2 + idempotency checks |
| **lock** | PreToolUse (Edit/Write) | -- | Advisory warning on entities/ | Required lock check |
| **rollup** | Stop (conditional) | -- | Optional (every N runs) | Mandatory (defined frequency) |

## 2c. Checkpoint -- confirm all files

List every file created in Phase 2 (tier-specific -- only list files relevant to the agent's classified tier). Use `AskUserQuestion`:

```
AskUserQuestion:
  question: "Here are the context and memory files I've created. Review the list -- anything missing or wrong?"
  options:
    - "Looks good, continue" -- proceed to Phase 3
    - "Need to add more files" -- user has additional context to capture
    - "Need to revise a file" -- user wants to edit something
```

Only proceed to Phase 3 after explicit approval.
