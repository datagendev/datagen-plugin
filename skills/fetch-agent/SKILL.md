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

### 4. Fetch the full registry for install details

Now fetch the template's manifest for detailed install info:

```bash
REPO_BASE="https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main"
TEMPLATE_PATH="TEMPLATE_PATH_FROM_INDEX"

curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/manifest.json" -o /tmp/datagen-manifest.json
```

### 5. Download template files

Download all template files from GitHub:

```bash
REPO_BASE="https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main"
TEMPLATE_PATH="TEMPLATE_PATH_FROM_INDEX"
TEMPLATE_ID="TEMPLATE_ID"

# Create local directories
mkdir -p $TEMPLATE_ID/{scripts,context,learnings,tmp}
mkdir -p .claude/agents

# Download agent definition
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/agent.md" -o ".claude/agents/$TEMPLATE_ID.md"

# Download manifest and docs
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/manifest.json" -o "$TEMPLATE_ID/manifest.json"
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/README.md" -o "$TEMPLATE_ID/README.md"
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/mcps.md" -o "$TEMPLATE_ID/mcps.md"

# Download scripts (read from manifest)
for script in $(python3 -c "
import json, urllib.request
manifest = json.loads(urllib.request.urlopen('$REPO_BASE/$TEMPLATE_PATH/manifest.json').read())
# List scripts based on the template -- hardcoded per template for reliability
import os
scripts_url = '$REPO_BASE/$TEMPLATE_PATH/scripts/'
# Known scripts for each template
known = {
    'linkedin-engagement': ['preflight.py', 'db.py', 'check_profiles.py', 'pull_engagements.py', 'dedup_contacts.py', 'enrich_batch.py', 'export.py'],
}
tid = '$TEMPLATE_ID'
for s in known.get(tid, []):
    print(s)
"); do
    curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/scripts/$script" -o "$TEMPLATE_ID/scripts/$script" 2>/dev/null
done

# Download context files
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/context/data-model.md" -o "$TEMPLATE_ID/context/data-model.md" 2>/dev/null

# Download learnings starter
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/learnings/common_failures_and_fix.md" -o "$TEMPLATE_ID/learnings/common_failures_and_fix.md" 2>/dev/null

# Create tmp/.gitkeep
touch "$TEMPLATE_ID/tmp/.gitkeep"
```

Replace `TEMPLATE_ID` and `TEMPLATE_PATH_FROM_INDEX` with actual values.

### 6. Update agent.md paths

The installed agent.md uses relative paths. Update them to point to the correct location:

Read the installed `.claude/agents/TEMPLATE_ID.md` and replace relative paths:
- `scripts/` -> `TEMPLATE_ID/scripts/`
- `context/` -> `TEMPLATE_ID/context/`
- `learnings/` -> `TEMPLATE_ID/learnings/`
- `tmp/` -> `TEMPLATE_ID/tmp/`
- `@context/` -> `@TEMPLATE_ID/context/`
- `@learnings/` -> `@TEMPLATE_ID/learnings/`

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

Check environment variables:

```bash
python3 -c "
import json, os
with open('/tmp/datagen-agents.json') as f:
    data = json.load(f)
agent = next(a for a in data['agents'] if a['id'] == 'TEMPLATE_ID')
missing = [v for v in agent.get('env_vars', []) if not os.environ.get(v)]
if missing:
    print('Missing required environment variables:')
    for v in missing:
        print(f'  export {v}=<value>')
else:
    print('All required environment variables are set.')
"
```

### 9. Install Python dependencies

```bash
python3 -c "
import json
with open('TEMPLATE_ID/manifest.json') as f:
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

Display the template's README.md as a post-install summary:

```bash
cat TEMPLATE_ID/README.md
```

Then tell the user how to invoke the agent:

```
Agent installed. To run it:
  @TEMPLATE_ID run the full pipeline

Or invoke a specific step:
  @TEMPLATE_ID just pull new posts
  @TEMPLATE_ID enrich pending contacts
```
