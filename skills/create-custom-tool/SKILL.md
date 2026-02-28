---
name: create-custom-tool
description: Create a custom tool with your own logic
user_invocable: true
---

# Create Custom Tool

Create a custom DataGen tool with your own logic, then test it using `executeCode`.

## When to invoke
- User wants to create a new custom tool
- User says "create tool", "custom tool", "build a tool"
- User has a specific automation they want to package as a reusable tool

## Before starting

**Create a task list first.** Use `TaskCreate` to create a task for each step below so the user can track progress. Mark each task `in_progress` when you start it and `completed` when done.

Tasks to create:
1. Check DataGen is configured
2. Research requirements and existing tools
3. Present the plan
4. Create the custom tool
5. Test and iterate
6. QA and code review
7. Submit a test run
8. Suggest next steps

## Steps

### 1. Check DataGen is configured

Verify `DATAGEN_API_KEY` is set. If not, suggest running `/datagen:setup` first.

### 2. Research requirements and existing tools

Ask the user:
- What should the tool do?
- What inputs does it need?
- What output should it return?
- Does it need access to any existing DataGen tools or external APIs?

Then gather context in parallel:
- Use `searchTools` to explore existing DataGen tools related to the user's requirements. This helps avoid building something that already exists, discover tools the custom tool can call or compose with, and learn input/output patterns from similar tools.
- Use `getCustomToolDetails` to check if the user already has custom tools or to understand the custom tool schema.
- If the tool needs external API keys, use `getUserSecrets` to check what credentials the user has stored. If a required secret is missing, guide the user to add it in the DataGen dashboard before proceeding.

### 3. Present the plan

Before building, summarize what you've learned from steps 1-2 and present a plan to the user for approval. Include:
- **Tool name and purpose**: What the tool will do
- **Inputs and outputs**: The parameter schema and expected return format
- **Existing tools to leverage**: Any DataGen tools discovered via `searchTools` that the custom tool will call or compose with
- **Credentials**: Which secrets from `getUserSecrets` will be used, or which new ones the user needs to add
- **Implementation approach**: High-level logic flow (e.g. "fetch data from X API, transform with Y, return Z")
- **Known constraints**: Rate limits, auth requirements, or edge cases to handle

After presenting the summary, use `AskUserQuestion` with options like:
- **Approve and build**: Proceed to implementation
- **Modify scope**: Let the user adjust requirements, then re-research and update the plan
- **Start over**: Go back to step 2 with fresh requirements

Do not proceed to step 4 until the user explicitly approves.

### 4. Create the custom tool

Use `updateCustomTool` to define the custom tool with:
- **Tool name and description**: Write a clear, specific description — this is what LLMs see when deciding whether to use the tool. Be explicit about what it does, not vague.
- **Input parameter schema**: Define each parameter with types and descriptions.
- **Implementation logic** (Python code):
  - Use `getUserSecrets` for API keys — never hardcode credentials
  - Return structured data (dict/JSON), not raw strings
  - Keep the tool focused on one task — compose multiple tools for complex workflows rather than building one monolithic tool

### 5. Test and iterate

Use the `executeCode` MCP tool to test the custom tool works correctly. This is the ONE case where `executeCode` should be used — for testing custom tools you just created.

Run the tool with sample inputs and verify the output matches expectations. If the test reveals issues:
- Update the tool definition with `updateCustomTool`
- Re-test with `executeCode`
- Repeat until the tool works as expected

### 6. QA and code review

After the executeCode test passes, perform a deep code review of the tool implementation:

- **Edge cases**: Test with empty inputs, missing fields, unexpected data types, large payloads, and boundary values
- **API rate limits**: If the tool calls external APIs, ensure it respects rate limits (add retries with backoff, handle 429 responses, batch requests where possible)
- **Error handling**: Verify the tool fails gracefully with clear error messages rather than crashing on bad input
- **Security**: Check for injection risks, hardcoded credentials, or unsafe data handling
- **Performance**: Look for unnecessary loops, redundant API calls, or memory-heavy operations
- **Code flow tracing**: Temporarily instrument the tool code with print statements at each key step (entry, API calls, data transforms, exit). Log both the execution path (e.g. `"Step: fetching data from API"`) and the data shape/values at each stage (e.g. `"Input: {...}, Output after transform: {...}"`). Run the instrumented version with `executeCode` using representative inputs, review the trace output to verify logic flows correctly and data transforms as expected, then remove all trace logging before finalizing with `updateCustomTool`.

Fix any issues found, update with `updateCustomTool`, and re-test with `executeCode` until the tool is robust.

### 7. Submit a test run

Use `submitCustomToolRun` to run the tool in the DataGen environment and `checkRunStatus` to monitor completion.

This runs in the DataGen cloud environment, which may behave differently from local `executeCode` testing (e.g. network access, timeouts, installed packages). If the run fails:
- Check the error output from `checkRunStatus` for environment-specific issues
- Fix with `updateCustomTool` and re-submit
- If the error is unclear, re-run with added print statements to diagnose, then clean them up after

### 8. Suggest next steps

- Use the custom tool in workflows via SDK (`/datagen:code-mode`) or MCP
- Deploy an agent that uses this tool with `/datagen:deploy-agent`
- Create more custom tools
