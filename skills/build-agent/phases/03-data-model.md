# Phase 3: Data model

This phase designs structured persistent data (DB schemas) and maps ephemeral in-run data flow. Context and memory markdown files were already created in Phase 2 -- this phase is about queryable storage and pipeline architecture.

## 3a. Decide if structured storage is needed

Does the agent need to persist entities across runs in a queryable store? Ask:

- Does the entity count grow over time? (new contacts each run, accumulating posts)
- Does the agent need to query historical data? (find contacts seen before, check if a post was already processed)
- Does the agent need dedup across runs? (skip already-enriched contacts)
- Does feedback need an audit trail? (who was flagged, when, why)

If all answers are "no" (one-shot, stateless agent), skip 3b and 3e -- the agent only needs `tmp/` files for in-run state and `memory/*.md` for cross-run context (all under `.datagen/agent/<agent-name>/`).

## 3b. Design tables

From 1b interview answers (entities, fields, dedup keys, lifecycle), design SQL tables:

```sql
-- Example: LinkedIn lead scraper
CREATE TABLE IF NOT EXISTS contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    linkedin_url TEXT UNIQUE NOT NULL,      -- dedup key
    name TEXT,
    headline TEXT,
    company TEXT,
    status TEXT DEFAULT 'new',              -- lifecycle: new -> enriched -> reviewed -> exported
    score REAL,
    source_post_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Feedback audit table (from 1d interview)
CREATE TABLE IF NOT EXISTS contact_feedback (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_id INTEGER REFERENCES contacts(id),
    verdict TEXT NOT NULL,                  -- 'good_fit' | 'not_good_fit'
    reason TEXT,                            -- user's explanation
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_contacts_status ON contacts(status);
CREATE INDEX idx_contacts_linkedin ON contacts(linkedin_url);
```

For each table, define:
- Columns with types and constraints
- Primary key and unique keys (dedup)
- Indexes for common queries
- Status/lifecycle column if the entity has states

## 3c. Design ephemeral flow

Map `tmp/` files for in-run pipeline data (under `.datagen/agent/<agent-name>/tmp/`). These are intermediate outputs that don't survive between runs.

For each step in the workflow, map what the **agent** reads and decides vs what a **script** handles:

| Step | Agent decides | Script handles | Output |
|------|--------------|----------------|--------|
| 1. Parse input | What format is this? Which fields matter? | Parse CSV/JSON, normalize | `tmp/parsed.json` |
| 2. Enrich | Which records need enrichment? Skip duplicates? | Batch API calls, rate limiting | `tmp/enriched.json` |
| 3. Score | Apply criteria from `context/criteria.md` | Number crunching on large datasets | `tmp/scored.json` |
| 4. Decide | Which records pass? What action for each? | -- (agent's job) | -- |
| 5. Output | Format selection, error summary | Write to CRM, send emails | `tmp/export_log.json` |

This table is the blueprint for the agent definition. The "Agent decides" column becomes agent steps. The "Script handles" column becomes helper scripts.

## 3d. Write data model doc

Save as `.datagen/agent/<agent-name>/context/data-model.md` with both DB schema and ephemeral flow:

```markdown
# Data Model

## Database Schema
<!-- SQL CREATE TABLE statements from 3b -->

## Entities
- **Contact**: linkedin_url (unique), name, headline, company, score
  - Lifecycle: new -> enriched -> reviewed -> exported
  - Dedup key: linkedin_url

## Ephemeral Storage (tmp/)
- `.datagen/agent/<agent-name>/tmp/scraped.json` -- raw scrape output, single-run only
- `.datagen/agent/<agent-name>/tmp/enriched.json` -- enrichment results before scoring

## Agent-script data flow
| Step | Agent decides | Script handles | Output |
|------|--------------|----------------|--------|
| ... | ... | ... | ... |
```

## 3e. Run migration

If using a database (Neon, Turso, SQLite, etc.), run the CREATE TABLE statements:

```python
# .datagen/agent/<agent-name>/scripts/migrate.py
import sqlite3  # or appropriate driver

conn = sqlite3.connect(".datagen/agent/<agent-name>/data/agent.db")
cursor = conn.cursor()

# Run CREATE TABLE statements from 3b
cursor.executescript("""
    -- paste SQL from 3b here
""")

conn.commit()
conn.close()
print("Migration complete")
```

For hosted databases (Turso, Neon), use the appropriate SDK or CLI. Save the migration script in `.datagen/agent/<agent-name>/scripts/migrate.py` so it can be re-run.

## 3f. Optional: Eviction, write-back, and hooks

If the agent runs repeatedly and accumulates entities:

- **Eviction**: entities not seen in N days can be archived or removed from active queries
- **Write-back script**: `.datagen/agent/<agent-name>/scripts/write_memory.py` that updates both `memory/*.md` (L1) and DB (L2) after each run
- **Stop hook**: check if memory files were updated during the run (see hook config pattern below)

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bash .datagen/agent/<agent-name>/scripts/memory_hook.sh" }
        ]
      }
    ]
  }
}
```

Define eviction thresholds and write-back rules in `.datagen/agent/<agent-name>/context/data-model.md`.

## 3g. CHECKPOINT -- Review data model with the user

**Do NOT proceed to Phase 4 until the user approves the data model.**

After saving `.datagen/agent/<agent-name>/context/data-model.md`, present it to the user for review. Use `AskUserQuestion`:

```
AskUserQuestion:
  question: "Here's the data model I've designed. Review it above -- does this look right, or do you want to change anything?"
  options:
    - "Looks good, continue" -- proceed to Phase 4
    - "Change entities/fields" -- user wants to modify what's tracked
    - "Change the step flow" -- user wants to reorder or add/remove steps
    - "Skip DB, keep it simple" -- use only tmp/ and memory/ markdown, no database
```

If the user requests changes, apply them, present again, and loop until approved.
