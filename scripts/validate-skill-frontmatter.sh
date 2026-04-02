#!/bin/bash
# Validate .claude/skills/*/SKILL.md files have correct frontmatter.
# Runs as a PostToolUse hook on Write|Edit.
#
# Required fields: name, description
# Allowed fields:  name, description, model, user_invocable, license, argument-hint
#
# Exit 0 = pass, exit 2 = block (feedback sent to Claude via stderr).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only validate SKILL.md files inside a .claude/skills/<name>/ directory
if [[ ! "$FILE_PATH" =~ \.claude/skills/[^/]+/SKILL\.md$ ]]; then
  exit 0
fi

# File must exist (PostToolUse means it was just written/edited)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# ── Extract frontmatter ──────────────────────────────────────────────
# Skills must have frontmatter.
if ! head -n 1 "$FILE_PATH" | grep -q '^---[[:space:]]*$'; then
  echo "Skill file must start with YAML frontmatter (---). File: $FILE_PATH" >&2
  exit 2
fi

# Get content between first and second --- (exclusive)
FRONTMATTER=$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c==1{print} c>=2{exit}' "$FILE_PATH")

if [ -z "$FRONTMATTER" ]; then
  echo "Skill file has empty frontmatter. Required fields: name, description. File: $FILE_PATH" >&2
  exit 2
fi

# ── Check required fields ────────────────────────────────────────────
REQUIRED=("name" "description")
for field in "${REQUIRED[@]}"; do
  if ! echo "$FRONTMATTER" | grep -qE "^${field}[[:space:]]*:"; then
    echo "Skill file missing required frontmatter field: '${field}'. File: $FILE_PATH" >&2
    exit 2
  fi
done

# ── Check for unsupported fields ─────────────────────────────────────
ALLOWED_PATTERN="^(name|description|model|user_invocable|license|argument-hint)$"

# Extract top-level keys (non-indented lines with key: pattern)
KEYS=$(echo "$FRONTMATTER" | grep -oE '^[a-zA-Z_][a-zA-Z0-9_-]*[[:space:]]*:' | sed 's/[[:space:]]*://')

for key in $KEYS; do
  if ! echo "$key" | grep -qE "$ALLOWED_PATTERN"; then
    echo "Skill file has unsupported frontmatter field: '${key}'. Allowed: name, description, model, user_invocable, license, argument-hint. File: $FILE_PATH" >&2
    exit 2
  fi
done

# ── Validate field values ────────────────────────────────────────────
# name must be lowercase + hyphens only
NAME_VAL=$(echo "$FRONTMATTER" | grep -E '^name[[:space:]]*:' | head -1 | sed 's/^name[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$NAME_VAL" ] && ! echo "$NAME_VAL" | grep -qE '^[a-z][a-z0-9-]*$'; then
  echo "Skill 'name' must be lowercase letters, numbers, and hyphens (e.g., 'my-skill'). Got: '${NAME_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

# model must be one of the allowed values (if present)
MODEL_VAL=$(echo "$FRONTMATTER" | grep -E '^model[[:space:]]*:' | head -1 | sed 's/^model[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$MODEL_VAL" ] && ! echo "$MODEL_VAL" | grep -qE '^(sonnet|opus|haiku|inherit)$'; then
  echo "Skill 'model' must be one of: sonnet, opus, haiku, inherit. Got: '${MODEL_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

# user_invocable must be boolean (if present)
UI_VAL=$(echo "$FRONTMATTER" | grep -E '^user_invocable[[:space:]]*:' | head -1 | sed 's/^user_invocable[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$UI_VAL" ] && ! echo "$UI_VAL" | grep -qE '^(true|false)$'; then
  echo "Skill 'user_invocable' must be true or false. Got: '${UI_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

exit 0
