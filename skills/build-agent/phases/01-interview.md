# Phase 1: Interview the user

Understand the job through four focused conversations. Do NOT skip this phase -- it produces the context layer that makes the agent reliable. Run each part as a separate `AskUserQuestion` round.

## 1a. Intent -- what's the goal?

Understand the job-to-be-done at a high level before diving into details.

**Ask:**

1. **What job should this agent do? Describe it like you'd explain it to a new hire.**
   - Get the end-to-end workflow in plain language: what triggers it, what it does, what it produces
   - Listen for: is this a daily routine, an event-driven reaction, or on-demand?
   - Save as `.datagen/agent/<agent-name>/context/goal.md`

2. **What does "good" output look like?**
   - Ask for an example, template, or screenshot of the ideal result
   - If the user has one, save it as `.datagen/agent/<agent-name>/context/output-template.md`

3. **What rules or judgment calls does this job require?**
   - Scoring rubrics, filtering logic, routing rules, "use your judgment" moments
   - These become the agent reasoning steps (not scripts)
   - Save as `.datagen/agent/<agent-name>/context/criteria.md`

## 1b. Data model -- what are the nouns?

Understand the entities the agent works with and how they flow through the pipeline.

**Ask:**

1. **What are the main things this agent tracks?** (contacts, companies, posts, tickets, etc.)
   - For each entity: what fields matter? What's the unique key (dedup)?
   - How does the user organize this data today? (spreadsheet, CRM, mental model)

2. **What lifecycle does each entity go through?**
   - Example: `new -> enriched -> scored -> exported`
   - What status changes does the agent make vs the user?

3. **Where should this data live?**

   Default recommendation: **use a database** (Turso, Neon, Supabase) as the primary store. Databases give you dedup, querying, lifecycle tracking, and audit trails out of the box. Recommend a database unless the user has a strong reason not to.

   If the user prefers flat files or already has a workflow around them, fall back to **structured exports** (CSV for tabular data, JSON for nested/API-style data). These work well as final outputs but are poor as working storage for agents that run repeatedly.

   **Ask:**
   - Where does your input data come from? (APIs, CRM exports, spreadsheets, manual lists)
   - Where should results end up? (CRM, spreadsheet, Slack, email, dashboard, database)
   - Does the agent need to remember what it already processed across runs? (If yes → database is the right call)

   **Guide on what tables are typically needed:**
   - **One entity table per noun** from question 1 (e.g., `contacts`, `companies`, `posts`) -- with a unique key for dedup, a `status` column for lifecycle, and `created_at`/`updated_at` timestamps
   - **A feedback table** if the agent has a feedback loop (from 1d) -- links back to the entity table, stores verdict + reason + timestamp
   - **A runs/log table** (optional) if the user wants to track what the agent did each run -- useful for debugging and audit

   This feeds directly into Phase 3 (data model design), where these tables get fully specified.

Save entity notes -- they'll become `.datagen/agent/<agent-name>/context/data-model.md` in Phase 3.

## 1c. Context sources -- what does the agent need to know?

Identify the knowledge the agent needs beyond the data it processes.

**Ask:**

1. **What domain knowledge does this job assume?**
   - Glossaries, org context, industry terms, "watch out for" rules
   - Things a new team member would need to know on day one
   - Save as `.datagen/agent/<agent-name>/context/domain-context.md`

2. **Are there reference lists or lookup tables the agent needs?**
   - Target account lists, influencer watchlists, keyword dictionaries, ICP definitions
   - These become context files the agent reads each run

3. **What preferences or rules should the agent follow?**
   - User-specific filters, scoring weights, output format preferences
   - These go in `.datagen/agent/<agent-name>/memory/preferences.md` -- editable anytime without touching the agent definition

## 1d. Feedback loop -- how does the agent get better?

Understand how the user will correct and improve the agent over time. This is critical for agents that run repeatedly.

**Ask:**

1. **When the agent shows you results, what would make you say "this one's wrong" or "skip this kind in the future"?**
   - Listen for: what does a bad result look like? What patterns should be filtered out?
   - This tells you what the feedback mechanism needs to capture

2. **How do you want to give that feedback?** (pick the simplest option that works)
   - Flag bad results during the run ("these 2 are not good fits")
   - Rate results after the run (thumbs up/down)
   - Edit a preferences file directly
   - The answer shapes whether you need a feedback script or just a memory file

3. **Should the agent learn from that feedback automatically, or should you review what it learned?**
   - Auto-learn: agent updates `.datagen/agent/<agent-name>/memory/feedback_learnings.md` directly
   - Review-first: agent proposes a learning, user approves before it's saved
   - This decides the feedback write-back pattern

**Key design decision:** feedback should target a specific agent step. For example, if the agent filters posts (Step 3) and filters commenters (Step 5), user feedback on "bad leads" improves Step 5 only -- don't let it bleed into Step 3 unless the user says so.

Save feedback design notes -- they'll feed into Phase 2 (memory files) and Phase 3 (feedback DB table if needed).

## 1e. Organize the context layer

```bash
mkdir -p .datagen/agent/<agent-name>/{context,memory,tmp,scripts,learnings,data}
```

Create files based on interview answers:

| File | Content | From |
|------|---------|------|
| `context/output-template.md` | Example of ideal output | 1a |
| `context/criteria.md` | Decision rules, scoring, filtering logic | 1a |
| `context/domain-context.md` | Background knowledge, glossaries, edge cases | 1c |
| `memory/preferences.md` | User rules and preferences | 1c |

All paths above are relative to `.datagen/agent/<agent-name>/`. These are placeholders -- Phase 2 will draft the actual file contents from interview answers and get user approval before saving.

## 1f. CHECKPOINT -- Present the blueprint

**Do NOT start Phase 2 until the user approves this summary.**

After all four interview rounds, present a single consolidated summary so the user can see the full picture of what this agent will look like. Use the template below -- fill in every section from interview answers.

```markdown
## Agent Blueprint: <agent name>

### What it does
<1-2 sentence summary of the job from 1a>

### Data model
| Entity | Key fields | Dedup key | Lifecycle |
|--------|-----------|-----------|-----------|
| <from 1b> | ... | ... | ... |

**Structured storage needed?** <yes/no + why -- e.g., "yes, entity count grows each run and needs cross-run dedup">

### Skills & tools (early estimate -- Phase 4 will finalize)
| Capability needed | Likely approach | Status |
|-------------------|----------------|--------|
| <from 1a workflow> | skill / tool / script -- best guess | unknown -- will verify in Phase 4 |

### Context files (Phase 2 will write these)
All under `.datagen/agent/<agent-name>/`:
- `context/output-template.md` -- <what it contains>
- `context/criteria.md` -- <what rules>
- `context/domain-context.md` -- <what knowledge>
- <any reference lists from 1c>

### Memory & persistence
All under `.datagen/agent/<agent-name>/`:
- `memory/preferences.md` -- <what preferences from 1c>
- `memory/feedback_learnings.md` -- <skip patterns, quality signals>
- **DB tables** (if needed): <entity table, feedback audit table from 1b/1d>

### Feedback loop
- **Trigger**: <what makes the user say "this is wrong" -- from 1d>
- **Capture method**: <flag during run / rate after / edit file -- from 1d>
- **Learning mode**: <auto-learn or review-first -- from 1d>
- **Target step**: <which agent step does feedback improve -- from 1d>
```

Present this to the user with `AskUserQuestion`:

```
AskUserQuestion:
  question: "Here's the full blueprint for this agent based on our interview. Does this capture everything correctly?"
  options:
    - "Looks good, start building" -- proceed to Phase 2
    - "Missing something" -- user wants to add info
    - "Something's wrong" -- user wants to correct a section
    - "Redo interview" -- start over
```

If the user requests changes, update the blueprint, present again, and loop until approved. Only after explicit approval, mark the Phase 1 task as completed and proceed to Phase 2.
