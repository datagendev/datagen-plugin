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

### Script template

```python
import os
import json
from datagen_sdk import DatagenClient

if not os.getenv("DATAGEN_API_KEY"):
    raise RuntimeError("DATAGEN_API_KEY not set")

client = DatagenClient()

# -- Replace with actual tool calls --
result = client.execute_tool("tool_alias", {"param": "value"})

# Save large output to file instead of printing
with open("output.json", "w") as f:
    json.dump(result, f, indent=2)

print(f"Results saved to output.json ({len(result)} records)")
```

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
