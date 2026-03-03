# Phase 5: Prototype with small helper scripts

Now build the helper scripts the agent will call. Each script handles one specific task -- the agent orchestrates them.

**Important: Use the code-mode pattern (local scripts with `DatagenClient().execute_tool()`), NOT `executeCode`.**

**Remember: Each script is a tool for the agent, not a replacement for it.** Keep scripts focused on data processing, API calls, and I/O. The agent handles reasoning, decisions, and coordination between scripts.

## 5a. Write one script per "Script handles" column from Phase 3c

Create a script that calls one or two tools via the SDK:

```python
import os, json
from datagen_sdk import DatagenClient

client = DatagenClient()

# Example: scrape a company website
result = client.execute_tool("mcp_Firecrawl_firecrawl_scrape", {
    "url": "https://example.com"
})

# Save output for inspection
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

**By the end of Phase 5, you should have:**
- A `.datagen/agent/<agent-name>/scripts/` directory with one script per heavy-lifting task
- A `.datagen/agent/<agent-name>/tmp/` directory with real output from each step
- A clear understanding of which tools work, what parameters they need, and what the output looks like
- A clear separation: scripts do data work, agent does thinking work

> Prototyping captures real tool names, real parameters, and real edge cases. But remember -- these scripts are helpers the agent calls, not an end-to-end pipeline.
