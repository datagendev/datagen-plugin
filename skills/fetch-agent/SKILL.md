---
name: fetch-agent
description: Browse, fetch, and install pre-built agent templates from the DataGen agent templates repository
user_invocable: true
---

# Fetch Agent Template

Browse and install pre-built agent templates that work with DataGen.

## When to invoke

- User says "fetch agent", "install agent template", or "get agent"
- User runs `/datagen:fetch-agent` with or without an argument
- User wants to see available agent templates

## Arguments

- No argument: list all available templates from the agent index
- Template ID (e.g., `linkedin-engagement`): fetch and install that specific template

## Before starting

**Create a task list first.** Use `TaskCreate` to create a task for each step below so the user can track progress. Mark each task `in_progress` when you start it and `completed` when done.

If the user provided a template ID, create these tasks:
1. Fetch agent index
2. Display agent catalog
3. Validate template is installable
4. Fetch manifest and download files
5. Update agent paths
6. Check prerequisites (secrets + MCPs)
7. Install Python dependencies
8. Show post-install guide

If no template ID was given (browse mode), only create:
1. Fetch agent index
2. Display agent catalog

## Steps

### 1. Fetch the agent index

Download the agent index from GitHub -- this is the single source of truth for all available templates:

```bash
AGENTS_URL="https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main/agents.json"
curl -fsSL "$AGENTS_URL" -o /tmp/datagen-agents.json
```

If the fetch fails, inform the user and suggest checking their network connection.

### 2. Display the agent catalog (always show this first)

Parse and display the available agents as a catalog. Show ALL agents regardless of status:

```bash
python3 -c "
import json

with open('/tmp/datagen-agents.json') as f:
    data = json.load(f)

print('DataGen Agent Templates')
print('=' * 60)
print()

for agent in data['agents']:
    status_badge = '[AVAILABLE]' if agent['status'] == 'stable' else '[COMING SOON]'
    print(f\"  {agent['id']}  {status_badge}\")
    print(f\"    {agent['description']}\")
    print()

    # DataGen built-in tools
    tools = agent.get('datagen_tools', [])
    if tools:
        print(f\"    Built-in tools: {', '.join(tools)}\")

    # Required MCPs
    required = agent.get('datagen_mcps', {}).get('required', [])
    if required:
        for mcp in required:
            alts = mcp.get('alternatives', [])
            name = ' | '.join(alts) if alts else mcp['name']
            print(f\"    Required MCP:  {name} -- {mcp['purpose']}\")

    # Optional MCPs
    optional = agent.get('datagen_mcps', {}).get('optional', [])
    if optional:
        for mcp in optional:
            print(f\"    Optional MCP:  {mcp['name']} -- {mcp['purpose']}\")

    # Secrets (API keys)
    secrets = agent.get('secrets', [])
    if secrets:
        names = [s['name'] for s in secrets]
        print(f\"    Secrets:       {', '.join(names)}\")

    print(f\"    Tags: {', '.join(agent.get('tags', []))}\")
    print()

print('-' * 60)
print('Install a template:  /datagen:fetch-agent <agent-id>')
print('Connect MCP servers: https://app.datagen.dev/tools')
"
```

If no template ID was given, stop here.

### 3. Check if template is installable

Look up the requested template ID in the index:

```bash
python3 -c "
import json, sys

template_id = sys.argv[1]
with open('/tmp/datagen-agents.json') as f:
    data = json.load(f)

match = next((a for a in data['agents'] if a['id'] == template_id), None)
if not match:
    print(f'Agent \"{template_id}\" not found.')
    print('Run /datagen:fetch-agent to see available agents.')
    sys.exit(1)

if match['status'] != 'stable':
    print(f'Agent \"{template_id}\" is coming soon and not yet available for install.')
    print(f'Description: {match[\"description\"]}')
    sys.exit(1)

if not match.get('path'):
    print(f'Agent \"{template_id}\" has no installable path yet.')
    sys.exit(1)

print(json.dumps(match, indent=2))
" "TEMPLATE_ID"
```

Replace `TEMPLATE_ID` with the user's requested template. If not found or not stable, stop.

### 4. Fetch manifest and discover files to download

Fetch the template's `manifest.json` -- it contains a `files` array listing every file in the template:

```bash
REPO_BASE="https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main"
TEMPLATE_PATH="TEMPLATE_PATH_FROM_INDEX"

curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/manifest.json" -o /tmp/datagen-manifest.json
```

### 5. Download all template files from manifest

Read the `files` array from the manifest and download each file. This is fully dynamic -- no hardcoded file lists:

```bash
REPO_BASE="https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main"
TEMPLATE_PATH="TEMPLATE_PATH_FROM_INDEX"
TEMPLATE_ID="TEMPLATE_ID"

# Create directories and download all files listed in manifest
python3 -c "
import json, os, urllib.request

with open('/tmp/datagen-manifest.json') as f:
    manifest = json.load(f)

repo_base = '$REPO_BASE'
template_path = '$TEMPLATE_PATH'
template_id = '$TEMPLATE_ID'

# agent.md goes to .claude/agents/, everything else under .datagen/TEMPLATE_ID/
os.makedirs(f'.claude/agents', exist_ok=True)
os.makedirs(f'.datagen/{template_id}/tmp', exist_ok=True)

for filepath in manifest.get('files', []):
    remote_url = f'{repo_base}/{template_path}/{filepath}'

    if filepath == 'agent.md':
        local_path = f'.claude/agents/{template_id}.md'
    else:
        local_path = f'.datagen/{template_id}/{filepath}'

    os.makedirs(os.path.dirname(local_path), exist_ok=True)

    try:
        urllib.request.urlretrieve(remote_url, local_path)
        print(f'  OK  {local_path}')
    except Exception as e:
        print(f'  SKIP {filepath} ({e})')

# Also download manifest.json itself
urllib.request.urlretrieve(
    f'{repo_base}/{template_path}/manifest.json',
    f'.datagen/{template_id}/manifest.json'
)
print(f'  OK  .datagen/{template_id}/manifest.json')

# Create tmp/.gitkeep
open(f'.datagen/{template_id}/tmp/.gitkeep', 'w').close()
print(f'  OK  .datagen/{template_id}/tmp/.gitkeep')
print(f'\nDownloaded {len(manifest.get(\"files\", []))} files.')
"
```

Replace `TEMPLATE_ID` and `TEMPLATE_PATH_FROM_INDEX` with actual values from step 3.

### 6. Update agent.md paths (if needed)

Templates that already use `.datagen/TEMPLATE_ID/...` paths in their agent.md do NOT need path rewriting -- they work as-is after install.

Only rewrite paths if the agent.md still uses bare relative paths (e.g. `scripts/`, `context/`). In that case, read `.claude/agents/TEMPLATE_ID.md` and replace:
- `scripts/` -> `.datagen/TEMPLATE_ID/scripts/`
- `context/` -> `.datagen/TEMPLATE_ID/context/`
- `learnings/` -> `.datagen/TEMPLATE_ID/learnings/`
- `tmp/` -> `.datagen/TEMPLATE_ID/tmp/`
- `templates/` -> `.datagen/TEMPLATE_ID/templates/`

### 7. Download shared skills (if any)

Check the manifest for shared skills and download them:

```bash
mkdir -p .claude/skills/datagen-setup
curl -fsSL "$REPO_BASE/_shared/skills/datagen-setup/SKILL.md" -o ".claude/skills/datagen-setup/SKILL.md" 2>/dev/null
```

### 8. Check prerequisites

**Built-in DataGen tools** (listed under `datagen_tools` in agents.json): Available automatically with a valid `DATAGEN_API_KEY`. No user action needed -- just confirm the API key is set.

**External MCP servers** (listed under `datagen_mcps` in agents.json): These require the user to connect them at app.datagen.dev/tools. For each required MCP:

1. Tell the user which MCP servers to connect and why
2. Suggest connecting via `/datagen:add-tools` or visiting https://app.datagen.dev/tools
3. For database MCPs with alternatives (Neon | Supabase), explain that either works -- the agent auto-detects which is connected

Check secrets (API keys and credentials):

```bash
python3 -c "
import json, os
with open('/tmp/datagen-agents.json') as f:
    data = json.load(f)
agent = next(a for a in data['agents'] if a['id'] == 'TEMPLATE_ID')
secrets = agent.get('secrets', [])
missing = []
for s in secrets:
    if s.get('required') and not os.environ.get(s['name']):
        missing.append(s)
if missing:
    print('Missing required secrets:')
    for s in missing:
        print(f\"  export {s['name']}=<value>  # {s['description']}\")
else:
    print('All required secrets are set.')
"
```

### 9. Install Python dependencies

```bash
python3 -c "
import json
with open('.datagen/TEMPLATE_ID/manifest.json') as f:
    manifest = json.load(f)
pkgs = manifest['requirements'].get('python_packages', [])
if pkgs:
    print('pip install ' + ' '.join(pkgs))
else:
    print('No Python packages required.')
"
```

Run the printed pip install command.

### 10. Show post-install guide

Read the template's README.md to understand what the agent does:

```bash
cat .datagen/TEMPLATE_ID/README.md
```

Then display an **Install Summary** that includes:

1. **What this agent does** -- a brief 2-3 sentence explanation based on the README and the agent's description from agents.json. Explain the workflow in plain language (e.g., "This agent fetches data from X, processes it, and delivers Y").
2. **Files installed** -- list the key paths (`.claude/agents/TEMPLATE_ID.md`, `.datagen/TEMPLATE_ID/`)
3. **Prerequisites status** -- which secrets and MCPs are ready vs missing
4. **How to invoke**:

```
To run it:
  @TEMPLATE_ID <describe what you want>

Examples:
  @TEMPLATE_ID run the full pipeline
  @TEMPLATE_ID just do step 1
```

5. **Reload reminder** -- Always end with:

```
IMPORTANT: Run `claude -r` to reload and pick up the new agent.
```
