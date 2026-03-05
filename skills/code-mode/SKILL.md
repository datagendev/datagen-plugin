---
name: code-mode
description: Write local Python scripts using the SDK for bulk/multi-step workflows
user_invocable: true
---

# Code Mode

Write and run local Python/TypeScript scripts using the DataGen SDK instead of making individual MCP tool calls.

## When to invoke
- Tool output is large and would flood the context window
- User needs to save tool results to local files (CSV, JSON, etc.)
- Batch processing: enriching many domains, processing a CSV, chaining 5+ tool calls
- Multi-step workflows that benefit from a single script execution
- User says "code mode", "write a script", "save to file", or asks for bulk operations

## Important: executeCode vs local scripts

- **Local scripts with SDK** -- use for ALL general workflows. Write a `.py` file and run it locally.
- **`executeCode` MCP tool** -- ONLY for testing custom tools created via `/datagen:create-custom-tool`. Do NOT use `executeCode` for general workflows.

## Before starting

**Create a task list first.** Use `TaskCreate` to create a task for each step so the user can track progress. Mark each task `in_progress` when you start it and `completed` when done.

Tasks to create:
1. Check prerequisites
2. Discover tools via MCP
3. Write the script
4. Run the script
5. Report results

## Steps

### 1. Check prerequisites

Verify:
- `DATAGEN_API_KEY` is set
- SDK is installed (`from datagen_sdk import DatagenClient` should work)
- If not installed, suggest running `/datagen:setup`

### 2. Discover tools via MCP

Before writing code, use MCP tools to discover what's needed:
- `searchTools` to find the right tool aliases
- `getToolDetails` to get the exact parameter schema

Do NOT guess tool names or parameter schemas -- always confirm via MCP first.

### 3. Write the script

Create a local Python script that:
- Imports and initializes the SDK client
- Calls the discovered tools with correct parameters
- Saves results to local files (CSV, JSON, etc.) instead of printing large output
- Handles errors appropriately

### MCP response parsing (required)

The SDK returns `{"content": [{"text": "JSON string"}]}`. Always parse with this helper:

```python
def parse_mcp_response(result):
    """Parse MCP tool response -- data is in content[0].text as JSON string."""
    if isinstance(result, dict) and "content" in result:
        text = result["content"][0].get("text", "")
        try:
            return json.loads(text)
        except (json.JSONDecodeError, TypeError):
            return text
    return result
```

### Script template (simple, no loop)

For one-shot scripts that make 1-2 API calls:

```python
import os, json
from datagen_sdk import DatagenClient

if not os.getenv("DATAGEN_API_KEY"):
    raise RuntimeError("DATAGEN_API_KEY not set")

client = DatagenClient()

def parse_mcp_response(result):
    if isinstance(result, dict) and "content" in result:
        text = result["content"][0].get("text", "")
        try:
            return json.loads(text)
        except (json.JSONDecodeError, TypeError):
            return text
    return result

result = parse_mcp_response(
    client.execute_tool("tool_alias", {"param": "value"})
)

with open("output.json", "w") as f:
    json.dump(result, f, indent=2)

print(f"Results saved to output.json ({len(result)} records)")
```

### Script template (durable, with loop)

**Every script that processes multiple items MUST be durable.** AI agents run long workflows with many API calls. Any call can timeout or fail. Scripts must checkpoint progress so they can resume from where they left off instead of restarting from scratch.

```python
import os, json
from datagen_sdk import DatagenClient

if not os.getenv("DATAGEN_API_KEY"):
    raise RuntimeError("DATAGEN_API_KEY not set")

client = DatagenClient()

TMP_DIR = "tmp"  # or .datagen/agent/<name>/tmp for agents
CHECKPOINT = f"{TMP_DIR}/script_checkpoint.json"
os.makedirs(TMP_DIR, exist_ok=True)


def parse_mcp_response(result):
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

### Durability rules

1. **Checkpoint after each item**, not just at the end. Save both processed IDs and accumulated results.
2. **Skip already-processed items** on resume. Load checkpoint at start, check each item against it.
3. **Clean up checkpoint on success.** Remove the checkpoint file when the full run completes.
4. **Print progress.** Show `[N/total]` so the agent (and user) can monitor how far along the script is.
5. **Parse MCP responses.** Always use `parse_mcp_response()` to unwrap SDK responses.
6. **Dedup against DB on subsequent runs.** If the script fetches data already in a database, check first and skip.

### 4. Run the script

Execute the script locally:

```bash
source .venv/bin/activate  # if using venv
python script_name.py
```

### 5. Report results

After execution, summarize what happened:
- How many records processed
- Where output files were saved
- Any errors encountered

Read the output file if the user wants to inspect results, but avoid dumping the entire contents into context if it's large -- instead summarize or show a sample.
