# Phase 3: Data model

This phase designs structured persistent data (DB schemas) and maps ephemeral in-run data flow. Context and memory markdown files were already created in Phase 2 -- this phase is about queryable storage and pipeline architecture.

## 3a. Decide if structured storage is needed

**Tier-aware heuristic** -- use the memory tier from Phase 1 (1d2) as a starting point:

- **Tier 1**: DB usually unnecessary. `STATE.md` + `tmp/` suffices for aggregate state and ephemeral processing. Only add a DB if entity count grows unboundedly across runs.
- **Tier 2**: DB almost always needed. `memory/entities/` handles working memory, but a DB provides dedup, querying, and long-term storage. The entities/ files are a cache layer over the DB.
- **Tier 3**: DB required. Add an `events` table with an idempotency key `UNIQUE` constraint to prevent duplicate processing under concurrent writes.

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

### Tier-specific table patterns

**Tier 2: decisions table** -- mirrors `memory/DECISIONS.md` for queryable audit:

```sql
CREATE TABLE IF NOT EXISTS decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    decision TEXT NOT NULL,
    rationale TEXT,
    outcome TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_decisions_entity ON decisions(entity_type, entity_id);
```

**Tier 3: events table** -- with idempotency enforcement for concurrent writes:

```sql
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    idempotency_key TEXT UNIQUE NOT NULL,
    event_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_events_entity ON events(entity_type, entity_id);
CREATE INDEX idx_events_type ON events(event_type);
```

Only create tier-specific tables matching the agent's classified tier.

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

## 3f. Eviction, write-back, and hooks

If the agent runs repeatedly and accumulates entities:

- **Eviction**: entities not seen in N days can be archived or removed from active queries
- **Write-back**: the `memory_flush.py` script (built in Phase 5) implements the **flush hook** for the agent's tier. It updates both `memory/` files (L1) and DB (L2) after each run.

The flush hook is tier-aware:
- **Tier 1**: updates `STATE.md`, appends `JOURNAL/` entry
- **Tier 2**: updates `STATE.md` + `PIPELINE.md` + entity files, appends `EVENTS.log` + `JOURNAL/`, optionally runs rollup
- **Tier 3**: same as Tier 2 + idempotency key checks, mandatory rollup at defined frequency

These scripts are wired to Claude Code via `.claude/settings.json` hooks (see Phase 5 for script templates and Phase 6 for hook configuration).

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
