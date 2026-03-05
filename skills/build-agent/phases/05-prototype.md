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

Build the memory lifecycle scripts that Claude Code hooks will call. The architecture uses three hooks:

1. **recall** (SessionStart, `type: command`) -- just prints `SUMMARY.md`. Fast, no processing.
2. **flush** (Stop, `type: command`) -- updates STATE.md, appends JOURNAL entry. Data work only.
3. **summarize** (Stop, `type: agent`) -- reads all memory files, writes compact `SUMMARY.md` (<10 lines). LLM-generated summary for the next session.

### `scripts/memory_recall.py` -- prints SUMMARY.md (all tiers)

The recall script is intentionally simple. The smart summary work happens in the agent hook on Stop.

```python
"""Memory recall -- prints SUMMARY.md if it exists."""
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
AGENT_DIR = os.path.dirname(SCRIPT_DIR)
SUMMARY_PATH = os.path.join(AGENT_DIR, "memory", "SUMMARY.md")

if os.path.exists(SUMMARY_PATH):
    with open(SUMMARY_PATH) as f:
        print(f.read().strip())
else:
    print("<agent-name>: no summary yet")
```

**Important:** Use `__file__`-based absolute paths, not relative paths. Hooks may run from any working directory.

### `scripts/memory_flush.py` -- updates state files (tier-specific)

The flush script handles data persistence. It runs as a command hook on Stop, before the agent summarize hook.

**Tier 1:**

```python
import os
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
AGENT_DIR = os.path.dirname(SCRIPT_DIR)
MEMORY_DIR = os.path.join(AGENT_DIR, "memory")
TMP_DIR = os.path.join(AGENT_DIR, "tmp")
JOURNAL_DIR = os.path.join(MEMORY_DIR, "JOURNAL")


def has_recent_run():
    """Only flush if tmp/ has files modified in the last 2 hours."""
    if not os.path.isdir(TMP_DIR):
        return False
    now = datetime.now().timestamp()
    for f in os.listdir(TMP_DIR):
        path = os.path.join(TMP_DIR, f)
        if os.path.isfile(path) and (now - os.path.getmtime(path)) < 7200:
            return True
    return False


def flush():
    if not has_recent_run():
        return

    os.makedirs(JOURNAL_DIR, exist_ok=True)
    now = datetime.now()

    # Update STATE.md
    state_path = os.path.join(MEMORY_DIR, "STATE.md")
    with open(state_path, "w") as f:
        f.write("# State\n\n")
        f.write("## Last run\n")
        f.write(f"- Date: {now.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"- Items processed: 0\n")
        f.write(f"- Outcome: completed\n")

    # Append JOURNAL entry
    journal_file = os.path.join(JOURNAL_DIR, f"{now.strftime('%Y-%m-%d_%H%M%S')}.md")
    with open(journal_file, "w") as f:
        f.write(f"# Session: {now.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write(f"## Summary\ncompleted\n")

    print(f"Memory flushed: STATE + JOURNAL")


if __name__ == "__main__":
    flush()
```

**Tier 2 (extends Tier 1):** Same structure but also updates `PIPELINE.md`, entity files in `entities/`, and appends to `EVENTS.log`. Adapt the `get_run_stats()` function to read from your agent's specific tmp output files.

**Tier 3:** Same as Tier 2 plus idempotency key generation and mandatory rollup check.

**Key rules for all flush scripts:**
- Use `__file__`-based absolute paths
- Guard with `has_recent_run()` so non-agent sessions don't write empty state
- Keep it fast -- this runs on every Stop event

### Summarize hook (agent, configured in settings.json)

The summarize hook is NOT a script -- it's a `type: agent` hook defined directly in `.claude/settings.json`. The agent subagent reads memory files and writes `SUMMARY.md`. See Phase 6 for the configuration.

**By the end of Phase 5, you should have:**
- A `.datagen/agent/<agent-name>/scripts/` directory with one script per heavy-lifting task
- A `.datagen/agent/<agent-name>/tmp/` directory with real output from each step
- A clear understanding of which tools work, what parameters they need, and what the output looks like
- A clear separation: scripts do data work, agent does thinking work
- **Every multi-item script uses the checkpoint/resume pattern** so it survives failures mid-run
- **DB dedup logic** so subsequent runs skip already-processed data instead of re-fetching
- **Memory hook scripts** (`memory_recall.py` and `memory_flush.py`) using absolute paths
- **No `memory_recall.py` parsing logic** -- recall just prints SUMMARY.md; the agent hook writes the smart summary

> Prototyping captures real tool names, real parameters, and real edge cases. But remember -- these scripts are helpers the agent calls, not an end-to-end pipeline.
