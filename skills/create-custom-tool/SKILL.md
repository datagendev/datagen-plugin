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
2. Understand tool requirements
3. Get custom tool details
4. Create the custom tool
5. Test with executeCode
6. Iterate and fix issues
7. Submit a test run

## Steps

### 1. Check DataGen is configured

Verify `DATAGEN_API_KEY` is set. If not, suggest running `/datagen:setup` first.

### 2. Understand the tool

Ask the user:
- What should the tool do?
- What inputs does it need?
- What output should it return?
- Does it need access to any existing DataGen tools or external APIs?

### 3. Get custom tool details

Use the DataGen MCP tool `getCustomToolDetails` to check if the user already has custom tools or to understand the custom tool schema.

### 4. Create or update the custom tool

Use `updateCustomTool` to define the custom tool with:
- Tool name and description
- Input parameter schema
- Implementation logic (Python code)

### 5. Test with executeCode

Use the `executeCode` MCP tool to test the custom tool works correctly. This is the ONE case where `executeCode` should be used -- for testing custom tools you just created.

Run the tool with sample inputs and verify the output matches expectations.

### 6. Iterate

If the test reveals issues:
- Update the tool definition with `updateCustomTool`
- Re-test with `executeCode`
- Repeat until the tool works as expected

### 7. Submit a test run

Use `submitCustomToolRun` to run the tool in the DataGen environment and `checkRunStatus` to monitor completion.

### 8. Suggest next steps

- Use the custom tool in workflows via SDK (`/datagen:code-mode`) or MCP
- Deploy an agent that uses this tool with `/datagen:deploy-agent`
- Create more custom tools
