# Phase 4: Explore tools and create skills

Now that you know the data model, context files, and memory structure (all under `.datagen/agent/<agent-name>/`), take inventory of what's available and **prioritize packaging capabilities as skills**. Skills are reusable, composable, and testable independently — they make agents modular instead of monolithic.

## 4a. Check existing skills first

Before looking for raw tools, check what reusable skills already exist:

```bash
ls -la .claude/skills/ 2>/dev/null
```

For each capability the agent needs, ask: **does an existing skill already handle this?** If yes, the agent just composes it (e.g., `/product-analysis`, `/enrich-company`). No new code needed.

## 4b. Discover available tools

Use `searchTools` and `getToolDetails` MCP tools to find what DataGen tools are available for this job:

```
searchTools -> find tools by intent (e.g., "scrape website", "send email", "search LinkedIn")
getToolDetails -> confirm exact input schema for each tool
```

For each tool the agent needs:
1. Search for it by intent
2. Get its full schema
3. Note the exact alias name (e.g., `mcp_Gmail_gmail_send_email`)

## 4c. Identify gaps and plan skills

After inventorying skills and tools, map each capability the agent needs to the right solution. **Default to creating a skill** when a capability is reusable across agents or encapsulates multi-step logic.

For each capability, decide:

| Question | If yes → | If no → |
|----------|----------|---------|
| Could another agent reuse this? | **Create a skill** | Keep as an inline script |
| Does it combine multiple tools into one workflow? | **Create a skill** | Single tool call is fine |
| Does it need its own context/criteria? | **Create a skill** with its own context files | Use the agent's context |
| Is it a simple API call with no judgment? | Keep as a helper script | **Create a skill** if judgment is involved |

## 4d. Create skills for reusable capabilities

For each capability that should be a skill, use `/datagen:create-skill` or scaffold manually in `.claude/skills/<skill-name>/`:

```
.claude/skills/<skill-name>/
├── SKILL.md          # instructions, when to invoke, input/output contract
└── scripts/          # helper scripts the skill uses
```

A good skill has:
- **A clear input/output contract** — what it receives, what it returns
- **Self-contained context** — doesn't rely on the parent agent's context files
- **A single responsibility** — one capability, well-defined scope

The agent definition will reference skills with `/skill-name` in its steps.

## 4e. Plan data preparation scripts

Skills handle reusable capabilities, but the agent still needs **agent-specific scripts** for data preparation — parsing inputs, normalizing formats, transforming between pipeline stages, and exporting results. These live in `.datagen/agent/<agent-name>/scripts/` and are built in Phase 5.

From the ephemeral flow table (Phase 3c), identify which "Script handles" entries are data prep vs reusable capabilities:

| Script type | Where it lives | Example |
|-------------|---------------|---------|
| **Data prep** (agent-specific) | `.datagen/agent/<agent-name>/scripts/` | `parse_input.py`, `normalize.py`, `export.py` |
| **Reusable capability** (cross-agent) | `.claude/skills/<skill-name>/` | `/enrich-company`, `/score-leads` |
| **One-off migration/setup** | `.datagen/agent/<agent-name>/scripts/` | `migrate.py`, `seed_data.py` |

**Example: LinkedIn lead scraper agent**

```
Agent step 1: Parse input
  → runs `scripts/parse_input.py` (data prep)
    reads user's CSV, normalizes column names, deduplicates, outputs tmp/parsed.json

Agent step 2: Enrich
  → calls `/enrich-company` skill (reusable — any agent can call this)
    skill takes company names, calls Firecrawl + Perplexity, returns enriched profiles
  → runs `scripts/merge_enrichment.py` (data prep)
    joins enrichment results back onto parsed records, outputs tmp/enriched.json

Agent step 3: Score
  → agent reads context/criteria.md and applies scoring logic directly
    (small dataset, no script needed — agent handles reasoning)

Agent step 4: Export
  → runs `scripts/export_to_crm.py` (data prep)
    formats scored records into CRM-ready CSV, writes to tmp/export.csv
```

The skills (`/enrich-company`) are reusable across agents. The scripts (`parse_input.py`, `merge_enrichment.py`, `export_to_crm.py`) are specific to this agent's pipeline — they handle the format transformations between stages.

## 4f. Fill remaining gaps

After creating skills and planning scripts, handle any remaining gaps:

| Gap type | Action |
|----------|--------|
| MCP server not connected | Suggest `/datagen:add-mcps` to connect the service |
| Custom logic needed | Suggest `/datagen:create-custom-tool` to build it |
| External API needed | Search online for MCP servers or APIs that provide it |

Use `WebSearch` to find MCP servers, APIs, or approaches that fill gaps.

## 4g. CHECKPOINT -- Present the skill & script plan to the user

**Do NOT proceed to Phase 5 until the user approves the plan.**

Show the user a clear map of what the agent will use. Be explicit about which skills and scripts are involved so the user knows exactly what's being built.

```markdown
## Agent Tooling Plan: <agent-name>

### Skills (reusable, in `.claude/skills/`)
| Skill | What it does | Status |
|-------|-------------|--------|
| `/enrich-company` | Enriches company data via Firecrawl + Perplexity | ✅ exists / 🔨 to create |
| `/score-leads` | Scores leads against ICP criteria | ✅ exists / 🔨 to create |

### Data prep scripts (agent-specific, in `.datagen/agent/<agent-name>/scripts/`)
| Script | What it does | Input → Output |
|--------|-------------|----------------|
| `parse_input.py` | Normalize user's CSV/JSON input | raw input → `tmp/parsed.json` |
| `merge_enrichment.py` | Join enrichment results onto records | skill output → `tmp/enriched.json` |
| `export_to_crm.py` | Format for CRM export | scored records → `tmp/export.csv` |

### Tools (MCP)
| Tool alias | Service | Used by |
|-----------|---------|---------|
| `mcp_Firecrawl_firecrawl_scrape` | Firecrawl | `/enrich-company` skill |
| `mcp_Gmail_gmail_send_email` | Gmail | Step 5 (notify) |

### Gaps still open
- <any unresolved gaps>
```

Present with `AskUserQuestion`:

```
AskUserQuestion:
  question: "Here's the full tooling plan — skills, scripts, and tools. Does this look right?"
  options:
    - "Looks good, start prototyping" -- proceed to Phase 5
    - "Add or change a skill" -- user wants to adjust skill scope
    - "Add or change a script" -- user wants to adjust data prep
    - "Missing a tool/service" -- need to connect something first
```

If the user requests changes, apply them and present again.
