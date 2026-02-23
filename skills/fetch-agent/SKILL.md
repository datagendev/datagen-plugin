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

- No argument: list all available templates
- Template ID (e.g., `linkedin-engagement`): fetch and install that specific template

## Steps

### 1. Fetch the registry

Download the template registry from GitHub:

```bash
REGISTRY_URL="https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main/registry.json"
curl -fsSL "$REGISTRY_URL" -o /tmp/datagen-registry.json
```

If the fetch fails, inform the user and suggest checking their network connection.

### 2. List templates (if no argument)

If no template ID was provided, parse and display the available templates:

```bash
python3 -c "
import json
with open('/tmp/datagen-registry.json') as f:
    registry = json.load(f)
print('Available agent templates:\n')
for t in registry['templates']:
    mcps = ', '.join(t.get('datagen_mcps', []))
    optional = ', '.join(t.get('datagen_mcps_optional', []))
    tags = ', '.join(t.get('tags', []))
    print(f\"  {t['id']}\")
    print(f\"    {t['description']}\")
    print(f\"    Category: {t['category']} | Tags: {tags}\")
    print(f\"    Required MCPs: {mcps}\")
    if optional:
        print(f\"    Optional MCPs: {optional}\")
    print()
print('Install a template with: /datagen:fetch-agent <template-id>')
"
```

Stop here if no template ID was given.

### 3. Find the template

Look up the requested template ID in the registry:

```bash
python3 -c "
import json, sys
template_id = sys.argv[1]
with open('/tmp/datagen-registry.json') as f:
    registry = json.load(f)
match = next((t for t in registry['templates'] if t['id'] == template_id), None)
if not match:
    print(f'Template \"{template_id}\" not found. Run /datagen:fetch-agent to see available templates.')
    sys.exit(1)
print(json.dumps(match, indent=2))
" "TEMPLATE_ID"
```

Replace `TEMPLATE_ID` with the user's requested template. If not found, stop and show available templates.

### 4. Download template files

Download all template files from GitHub using the template path from the registry:

```bash
REPO_BASE="https://raw.githubusercontent.com/datagendev/datagen-agent-templates/main"
TEMPLATE_PATH="templates/TEMPLATE_ID"

# Create local directories
mkdir -p TEMPLATE_ID/{scripts,context,learnings,tmp}
mkdir -p .claude/agents

# Download agent definition
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/agent.md" -o ".claude/agents/TEMPLATE_ID.md"

# Download manifest and docs
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/manifest.json" -o "TEMPLATE_ID/manifest.json"
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/README.md" -o "TEMPLATE_ID/README.md"
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/mcps.md" -o "TEMPLATE_ID/mcps.md"

# Download scripts
for script in $(python3 -c "
import json
with open('/tmp/datagen-registry.json') as f:
    registry = json.load(f)
# Fetch the manifest to get script list
import urllib.request
manifest_url = '$REPO_BASE/$TEMPLATE_PATH/manifest.json'
manifest = json.loads(urllib.request.urlopen(manifest_url).read())
# List known scripts based on template
print('preflight.py db.py check_profiles.py pull_engagements.py dedup_contacts.py enrich_batch.py export.py')
"); do
    curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/scripts/$script" -o "TEMPLATE_ID/scripts/$script" 2>/dev/null
done

# Download context files
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/context/data-model.md" -o "TEMPLATE_ID/context/data-model.md" 2>/dev/null

# Download learnings starter
curl -fsSL "$REPO_BASE/$TEMPLATE_PATH/learnings/common_failures_and_fix.md" -o "TEMPLATE_ID/learnings/common_failures_and_fix.md" 2>/dev/null

# Create tmp/.gitkeep
touch "TEMPLATE_ID/tmp/.gitkeep"
```

Replace `TEMPLATE_ID` with the actual template ID throughout.

### 5. Update agent.md paths

The installed agent.md uses relative paths like `scripts/` and `context/`. Update them to point to the correct location:

Read the installed `.claude/agents/TEMPLATE_ID.md` and replace relative paths:
- `scripts/` -> `TEMPLATE_ID/scripts/`
- `context/` -> `TEMPLATE_ID/context/`
- `learnings/` -> `TEMPLATE_ID/learnings/`
- `tmp/` -> `TEMPLATE_ID/tmp/`
- `@context/` -> `@TEMPLATE_ID/context/`
- `@learnings/` -> `@TEMPLATE_ID/learnings/`

### 6. Download shared skills (if any)

Check the manifest for shared skills and download them:

```bash
# Download shared datagen-setup skill if referenced
mkdir -p .claude/skills/datagen-setup
curl -fsSL "$REPO_BASE/_shared/skills/datagen-setup/SKILL.md" -o ".claude/skills/datagen-setup/SKILL.md" 2>/dev/null
```

### 7. Check prerequisites

**Built-in DataGen tools** (listed under `datagen_tools` in manifest): These are available automatically with a valid `DATAGEN_API_KEY`. No user action needed -- just confirm the API key is set.

**External MCP servers** (listed under `datagen_mcps` in manifest): These require the user to connect them at app.datagen.dev/tools. For each required server:

1. Check if it's connected by running `searchTools` for one of its tools
2. If not connected, prompt the user to connect it via `/datagen:add-tools`

Check environment variables listed in the manifest:

```bash
python3 -c "
import json, os
with open('TEMPLATE_ID/manifest.json') as f:
    manifest = json.load(f)
missing = []
for var in manifest['requirements']['env_vars']:
    if var['required'] and not os.environ.get(var['name']):
        missing.append(var['name'])
if missing:
    print('Missing required environment variables:')
    for v in missing:
        print(f'  export {v}=<value>')
else:
    print('All required environment variables are set.')
"
```

### 8. Install Python dependencies

```bash
pip install datagen-python-sdk psycopg2-binary
```

Or check the manifest for the exact list:

```bash
python3 -c "
import json
with open('TEMPLATE_ID/manifest.json') as f:
    manifest = json.load(f)
pkgs = manifest['requirements'].get('python_packages', [])
if pkgs:
    print('pip install ' + ' '.join(pkgs))
"
```

### 9. Show post-install guide

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
