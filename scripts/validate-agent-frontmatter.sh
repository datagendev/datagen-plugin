#!/bin/bash
# Validate .claude/agents/*.md files have correct frontmatter.
# Runs as a PostToolUse hook on Write|Edit.
#
# Required fields: name, description
# Allowed fields:  name, description, tools, disallowedTools, model,
#                  permissionMode, maxTurns, skills, mcpServers, hooks,
#                  memory, background, isolation
#
# Exit 0 = pass, exit 2 = block (feedback sent to Claude via stderr).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only validate files inside a .claude/agents/ directory
if [[ ! "$FILE_PATH" =~ \.claude/agents/[^/]+\.md$ ]]; then
  exit 0
fi

# File must exist (PostToolUse means it was just written/edited)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# ── Extract frontmatter ──────────────────────────────────────────────
# Frontmatter is everything between the first and second '---' lines.
if ! head -n 1 "$FILE_PATH" | grep -q '^---[[:space:]]*$'; then
  echo "Agent file must start with YAML frontmatter (---). File: $FILE_PATH" >&2
  exit 2
fi

# Get content between first and second --- (exclusive)
FRONTMATTER=$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c==1{print} c>=2{exit}' "$FILE_PATH")

if [ -z "$FRONTMATTER" ]; then
  echo "Agent file has empty frontmatter. Required fields: name, description. File: $FILE_PATH" >&2
  exit 2
fi

# ── Check required fields ────────────────────────────────────────────
REQUIRED=("name" "description")
for field in "${REQUIRED[@]}"; do
  if ! echo "$FRONTMATTER" | grep -qE "^${field}[[:space:]]*:"; then
    echo "Agent file missing required frontmatter field: '${field}'. File: $FILE_PATH" >&2
    exit 2
  fi
done

# ── Check for unsupported fields ─────────────────────────────────────
ALLOWED_PATTERN="^(name|description|tools|disallowedTools|model|permissionMode|maxTurns|skills|mcpServers|hooks|memory|background|isolation)$"

# Extract top-level keys (non-indented lines with key: pattern)
KEYS=$(echo "$FRONTMATTER" | grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*:' | sed 's/[[:space:]]*://')

for key in $KEYS; do
  if ! echo "$key" | grep -qE "$ALLOWED_PATTERN"; then
    echo "Agent file has unsupported frontmatter field: '${key}'. Allowed: name, description, tools, disallowedTools, model, permissionMode, maxTurns, skills, mcpServers, hooks, memory, background, isolation. File: $FILE_PATH" >&2
    exit 2
  fi
done

# ── Validate field values ────────────────────────────────────────────
# name must be lowercase + hyphens only
NAME_VAL=$(echo "$FRONTMATTER" | grep -E '^name[[:space:]]*:' | head -1 | sed 's/^name[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$NAME_VAL" ] && ! echo "$NAME_VAL" | grep -qE '^[a-z][a-z0-9-]*$'; then
  echo "Agent 'name' must be lowercase letters, numbers, and hyphens (e.g., 'my-agent'). Got: '${NAME_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

# model must be one of the allowed values (if present)
MODEL_VAL=$(echo "$FRONTMATTER" | grep -E '^model[[:space:]]*:' | head -1 | sed 's/^model[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$MODEL_VAL" ] && ! echo "$MODEL_VAL" | grep -qE '^(sonnet|opus|haiku|inherit)$'; then
  echo "Agent 'model' must be one of: sonnet, opus, haiku, inherit. Got: '${MODEL_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

# permissionMode must be one of the allowed values (if present)
PERM_VAL=$(echo "$FRONTMATTER" | grep -E '^permissionMode[[:space:]]*:' | head -1 | sed 's/^permissionMode[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$PERM_VAL" ] && ! echo "$PERM_VAL" | grep -qE '^(default|acceptEdits|dontAsk|bypassPermissions|plan)$'; then
  echo "Agent 'permissionMode' must be one of: default, acceptEdits, dontAsk, bypassPermissions, plan. Got: '${PERM_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

# memory must be one of the allowed values (if present)
MEM_VAL=$(echo "$FRONTMATTER" | grep -E '^memory[[:space:]]*:' | head -1 | sed 's/^memory[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$MEM_VAL" ] && ! echo "$MEM_VAL" | grep -qE '^(user|project|local)$'; then
  echo "Agent 'memory' must be one of: user, project, local. Got: '${MEM_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

# background must be boolean (if present)
BG_VAL=$(echo "$FRONTMATTER" | grep -E '^background[[:space:]]*:' | head -1 | sed 's/^background[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$BG_VAL" ] && ! echo "$BG_VAL" | grep -qE '^(true|false)$'; then
  echo "Agent 'background' must be true or false. Got: '${BG_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

# isolation must be 'worktree' (if present)
ISO_VAL=$(echo "$FRONTMATTER" | grep -E '^isolation[[:space:]]*:' | head -1 | sed 's/^isolation[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$ISO_VAL" ] && ! echo "$ISO_VAL" | grep -qE '^worktree$'; then
  echo "Agent 'isolation' must be 'worktree'. Got: '${ISO_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

exit 0
