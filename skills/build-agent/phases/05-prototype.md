# Phase 5: Prototype with small helper scripts

Now build the helper scripts the agent will call. Each script handles one specific task -- the agent orchestrates them.

**Important: Use the code-mode pattern (local scripts with `DatagenClient().execute_tool()`), NOT `executeCode`.**

**Remember: Each script is a tool for the agent, not a replacement for it.** Keep scripts focused on data processing, API calls, and I/O. The agent handles reasoning, decisions, and coordination between scripts.

## 5a. Write one script per "Script handles" column from Phase 3c

**Every script that processes multiple items MUST be durable.** AI agents run long workflows with many API calls. Any call can timeout or fail. Scripts must checkpoint progress so they can resume from where they left off instead of restarting from scratch.

### Durability pattern (required for all scripts that loop over items)

```python
import os, json
from datagen_sdk import DatagenClient

client = DatagenClient()

TMP_DIR = ".datagen/agent/<agent-name>/tmp"
CHECKPOINT = f"{TMP_DIR}/<script-name>_checkpoint.json"
os.makedirs(TMP_DIR, exist_ok=True)


def parse_mcp_response(result):
    """Parse MCP tool response -- data is in content[0].text as JSON string."""
    if isinstance(result, dict) and "content" in result:
        text = result["content"][0].get("text", "")
        try:
            return json.loads(text)
        except (json.JSONDecodeError, TypeError):
            return text
    return result


def save_checkpoint(data):
    with open(CHECKPOINT, "w") as f:
        json.dump(data, f, indent=2, default=str)


def load_checkpoint():
    if os.path.exists(CHECKPOINT):
        with open(CHECKPOINT) as f:
            return json.load(f)
    return None


# Resume from checkpoint if available
checkpoint = load_checkpoint()
if checkpoint:
    processed_ids = set(checkpoint.get("processed_ids", []))
    results = checkpoint.get("results", [])
    print(f"Resuming: {len(processed_ids)} items already done")
else:
    processed_ids = set()
    results = []

# Process items, skipping already-done ones
items = [...]  # load your input
for item in items:
    item_id = item["id"]  # unique identifier
    if item_id in processed_ids:
        continue

    try:
        result = parse_mcp_response(
            client.execute_tool("tool_alias", {"param": item["value"]})
        )
        results.append(result)
        processed_ids.add(item_id)
        save_checkpoint({"processed_ids": list(processed_ids), "results": results})
        print(f"  [{len(processed_ids)}/{len(items)}] Processed {item_id}")
    except Exception as e:
        print(f"  ERROR on {item_id}: {e}")
        save_checkpoint({"processed_ids": list(processed_ids), "results": results})
        print(f"  Checkpoint saved. Re-run to retry.")

# Save final output and clean up checkpoint
with open(f"{TMP_DIR}/output.json", "w") as f:
    json.dump(results, f, indent=2, default=str)

if os.path.exists(CHECKPOINT):
    os.remove(CHECKPOINT)
    print("Checkpoint cleaned up (run complete)")
```

### Key durability rules

1. **Checkpoint after each item**, not just at the end. Save both the set of processed IDs and accumulated results.
2. **Skip already-processed items** on resume. Load checkpoint at start, check each item against it.
3. **Clean up checkpoint on success.** Remove the checkpoint file when the full run completes so the next run starts fresh.
4. **Print progress.** Show `[N/total]` so the agent (and user) can monitor how far along the script is.
5. **Parse MCP responses.** The SDK returns `{"content": [{"text": "JSON string"}]}`. Always use `parse_mcp_response()` to unwrap.
6. **Dedup against DB on subsequent runs.** If the script fetches data that's already in the database, check the DB first and skip items already stored. This avoids redundant API calls across runs.

### Simple scripts (no loop) don't need checkpoints

For one-shot scripts that make 1-2 API calls, the basic pattern is fine:

```python
import os, json
from datagen_sdk import DatagenClient

client = DatagenClient()

result = client.execute_tool("mcp_Firecrawl_firecrawl_scrape", {
    "url": "https://example.com"
})

os.makedirs(".datagen/agent/<agent-name>/tmp", exist_ok=True)
with open(".datagen/agent/<agent-name>/tmp/scrape_result.json", "w") as f:
    json.dump(result, f, indent=2)

print("Saved to .datagen/agent/<agent-name>/tmp/scrape_result.json")
```

## 5b. Save output to `tmp/`

Every script saves its output as JSON or CSV in `.datagen/agent/<agent-name>/tmp/`. This follows the RLM pattern -- treat context as an external environment, use code to peek/grep/partition data.

```bash
mkdir -p .datagen/agent/<agent-name>/{tmp,scripts}
```

## 5c. Verify the output

After each script runs, read the output file and verify:
- Is the data structure what you expected?
- Are the fields populated correctly?
- Are there errors or missing data?

## 5d. Move to the next step

Once a script works, move to the next step of the workflow. Each script builds on the previous one's output.

## 5e. Build memory hook scripts

Build the memory lifecycle scripts that Claude Code hooks will call. These follow the same SDK patterns as other Phase 5 scripts. Create them based on the agent's memory tier from Phase 1 (1d2).

### `scripts/memory_recall.py` -- reads tier-appropriate memory files at session start

**Tier 1:**

```python
import os

AGENT_DIR = ".datagen/agent/<agent-name>"
MEMORY_DIR = f"{AGENT_DIR}/memory"

def recall():
    """Read memory files and print summary for Claude to see."""
    # Read STATE.md
    state_path = f"{MEMORY_DIR}/STATE.md"
    if os.path.exists(state_path):
        with open(state_path) as f:
            print("=== STATE ===")
            print(f.read())

    # Read preferences
    prefs_path = f"{MEMORY_DIR}/preferences.md"
    if os.path.exists(prefs_path):
        with open(prefs_path) as f:
            print("=== PREFERENCES ===")
            print(f.read())

if __name__ == "__main__":
    recall()
```

**Tier 2 (extends Tier 1):**

```python
import os, glob

AGENT_DIR = ".datagen/agent/<agent-name>"
MEMORY_DIR = f"{AGENT_DIR}/memory"

def recall():
    """Read memory files and print summary for Claude to see."""
    # Core files to always load
    for name, label in [
        ("PROFILE.md", "PROFILE"),
        ("STATE.md", "STATE"),
        ("PIPELINE.md", "PIPELINE"),
        ("preferences.md", "PREFERENCES"),
        ("feedback_learnings.md", "FEEDBACK LEARNINGS"),
    ]:
        path = f"{MEMORY_DIR}/{name}"
        if os.path.exists(path):
            with open(path) as f:
                print(f"=== {label} ===")
                print(f.read())

    # List entities (lazy -- just show what's available, don't load all)
    entity_files = glob.glob(f"{MEMORY_DIR}/entities/*.md")
    if entity_files:
        print(f"=== ENTITIES ({len(entity_files)} files) ===")
        for ef in sorted(entity_files)[:10]:
            print(f"  - {os.path.basename(ef)}")
        if len(entity_files) > 10:
            print(f"  ... and {len(entity_files) - 10} more")

    # Show recent events (last 20 lines)
    events_path = f"{MEMORY_DIR}/EVENTS.log"
    if os.path.exists(events_path):
        with open(events_path) as f:
            lines = f.readlines()
            print(f"=== RECENT EVENTS (last 20 of {len(lines)}) ===")
            for line in lines[-20:]:
                print(line.rstrip())

if __name__ == "__main__":
    recall()
```

**Tier 3:** Same as Tier 2 plus idempotency state check -- read last idempotency key from `EVENTS.log` and print it so the agent can continue the sequence.

### `scripts/memory_flush.py` -- updates tier-appropriate memory files at session end

**Tier 1:**

```python
import os
from datetime import datetime

AGENT_DIR = ".datagen/agent/<agent-name>"
MEMORY_DIR = f"{AGENT_DIR}/memory"
JOURNAL_DIR = f"{MEMORY_DIR}/JOURNAL"

def flush(summary: str = "", items_processed: int = 0):
    """Update STATE.md and append JOURNAL entry."""
    os.makedirs(JOURNAL_DIR, exist_ok=True)
    now = datetime.now()

    # Update STATE.md
    state_path = f"{MEMORY_DIR}/STATE.md"
    with open(state_path, "w") as f:
        f.write(f"# State\n\n")
        f.write(f"## Last run\n")
        f.write(f"- Date: {now.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"- Items processed: {items_processed}\n")
        f.write(f"- Outcome: {summary or 'completed'}\n")

    # Append JOURNAL entry
    journal_file = f"{JOURNAL_DIR}/{now.strftime('%Y-%m-%d_%H%M%S')}.md"
    with open(journal_file, "w") as f:
        f.write(f"# Session: {now.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"## Summary\n{summary}\n\n")
        f.write(f"## Items processed: {items_processed}\n")

    print(f"Memory flushed: STATE updated, journal entry at {os.path.basename(journal_file)}")

if __name__ == "__main__":
    flush()
```

**Tier 2 (extends Tier 1):**

```python
import os
from datetime import datetime

AGENT_DIR = ".datagen/agent/<agent-name>"
MEMORY_DIR = f"{AGENT_DIR}/memory"
JOURNAL_DIR = f"{MEMORY_DIR}/JOURNAL"

def flush(summary="", items_processed=0, pipeline_state=None, events=None):
    """Update all state files and append EVENTS + JOURNAL."""
    os.makedirs(JOURNAL_DIR, exist_ok=True)
    now = datetime.now()

    # Update STATE.md (same as T1)
    state_path = f"{MEMORY_DIR}/STATE.md"
    with open(state_path, "w") as f:
        f.write(f"# State\n\n## Last run\n")
        f.write(f"- Date: {now.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"- Items processed: {items_processed}\n")
        f.write(f"- Outcome: {summary or 'completed'}\n")

    # Update PIPELINE.md if state provided
    if pipeline_state:
        pipeline_path = f"{MEMORY_DIR}/PIPELINE.md"
        with open(pipeline_path, "w") as f:
            f.write("# Pipeline State\n\n## Active stages\n")
            f.write("| Entity ID | Type | Stage | Entered | Blocked by |\n")
            f.write("|-----------|------|-------|---------|------------|\n")
            for entry in pipeline_state:
                f.write(f"| {entry.get('id','')} | {entry.get('type','')} | {entry.get('stage','')} | {entry.get('entered','')} | {entry.get('blocked_by','')} |\n")

    # Append to EVENTS.log
    if events:
        events_path = f"{MEMORY_DIR}/EVENTS.log"
        with open(events_path, "a") as f:
            for event in events:
                f.write(f"[{now.isoformat()}] [{event['type']}] {event['entity']}: {event['description']}\n")

    # Append JOURNAL entry
    journal_file = f"{JOURNAL_DIR}/{now.strftime('%Y-%m-%d_%H%M%S')}.md"
    with open(journal_file, "w") as f:
        f.write(f"# Session: {now.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"## Summary\n{summary}\n\n")
        f.write(f"## Items processed: {items_processed}\n")
        if events:
            f.write(f"\n## Events logged: {len(events)}\n")

    print(f"Memory flushed: STATE, PIPELINE, EVENTS, JOURNAL updated")

if __name__ == "__main__":
    flush()
```

**Tier 3:** Same as Tier 2 plus: generate idempotency keys per event (`<agent-name>_<run-id>_<step>_<entity-id>`), dedup check against existing `EVENTS.log` before appending, and mandatory rollup check against threshold in `PROFILE.md`.

Adapt the templates above to the agent's specific entity types and pipeline stages. These scripts are called by Claude Code hooks configured in `.claude/settings.json` (see Phase 6).

**By the end of Phase 5, you should have:**
- A `.datagen/agent/<agent-name>/scripts/` directory with one script per heavy-lifting task
- A `.datagen/agent/<agent-name>/tmp/` directory with real output from each step
- A clear understanding of which tools work, what parameters they need, and what the output looks like
- A clear separation: scripts do data work, agent does thinking work
- **Every multi-item script uses the checkpoint/resume pattern** so it survives failures mid-run
- **DB dedup logic** so subsequent runs skip already-processed data instead of re-fetching
- **Memory hook scripts** (`memory_recall.py` and `memory_flush.py`) matching the agent's tier

> Prototyping captures real tool names, real parameters, and real edge cases. But remember -- these scripts are helpers the agent calls, not an end-to-end pipeline.
