---
name: fetch-skill
description: Browse, fetch, and install reusable skills from the DataGen agent templates repository
user_invocable: true
---

# Fetch Skill

Browse and install reusable skills that work with DataGen.

## When to invoke

- User says "fetch skill", "install skill", or "get skill"
- User runs `/datagen:fetch-skill` with or without an argument
- User wants to see available skills

## Arguments

- No argument: browse mode -- list all available skills
- Skill ID (e.g., `enrich-company`): install that specific skill

## Steps

### 1. Determine mode and run the install script

The install script is at `${CLAUDE_PLUGIN_ROOT}/scripts/install-skill.py`. It handles all fetching, validation, downloading, path remapping, and prerequisite checks internally.

**Browse mode** (no skill ID given):

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/install-skill.py" --browse
```

**Install mode** (skill ID given):

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/install-skill.py" --install <skill-id>
```

Replace `<skill-id>` with the user's requested skill ID.

Show the script output directly to the user.

### 2. Post-install actions (install mode only)

If the script output includes a `pip install` line under "Python dependencies required", run that pip command.

If the script output lists "Required MCP servers", remind the user they can connect them via `/datagen:add-tools` or at https://app.datagen.dev/tools.

### Exit codes

The script uses these exit codes:
- **0**: success
- **1**: network error (suggest checking connection)
- **2**: skill not found (suggest running browse mode)
- **3**: skill is coming soon (inform user it's not yet available)
- **4**: skill has no installable path
