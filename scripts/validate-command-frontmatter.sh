#!/bin/bash
# Validate .claude/commands/*.md files have correct frontmatter.
# Runs as a PostToolUse hook on Write|Edit.
#
# Commands may have NO frontmatter (plain markdown is valid).
# If frontmatter is present:
#   No required fields
#   Allowed fields: name, description, model, argument-hint
#
# Exit 0 = pass, exit 2 = block (feedback sent to Claude via stderr).

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only validate files inside a .claude/commands/ directory
if [[ ! "$FILE_PATH" =~ \.claude/commands/[^/]+\.md$ ]]; then
  exit 0
fi

# File must exist (PostToolUse means it was just written/edited)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# ── Check for frontmatter ───────────────────────────────────────────
# Commands are allowed without frontmatter -- if no frontmatter, pass.
if ! head -n 1 "$FILE_PATH" | grep -q '^---[[:space:]]*$'; then
  exit 0
fi

# Get content between first and second --- (exclusive)
FRONTMATTER=$(awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c==1{print} c>=2{exit}' "$FILE_PATH")

if [ -z "$FRONTMATTER" ]; then
  # Empty frontmatter block is fine for commands
  exit 0
fi

# ── Check for unsupported fields ─────────────────────────────────────
ALLOWED_PATTERN="^(name|description|model|argument-hint)$"

# Extract top-level keys (non-indented lines with key: pattern)
KEYS=$(echo "$FRONTMATTER" | grep -oE '^[a-zA-Z_][a-zA-Z0-9_-]*[[:space:]]*:' | sed 's/[[:space:]]*://')

for key in $KEYS; do
  if ! echo "$key" | grep -qE "$ALLOWED_PATTERN"; then
    echo "Command file has unsupported frontmatter field: '${key}'. Allowed: name, description, model, argument-hint. File: $FILE_PATH" >&2
    exit 2
  fi
done

# ── Validate field values ────────────────────────────────────────────
# name: no strict validation for commands (human-readable names with spaces/capitals are common)

# model must be one of the allowed values (if present)
MODEL_VAL=$(echo "$FRONTMATTER" | grep -E '^model[[:space:]]*:' | head -1 | sed 's/^model[[:space:]]*:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -n "$MODEL_VAL" ] && ! echo "$MODEL_VAL" | grep -qE '^(sonnet|opus|haiku|inherit)$'; then
  echo "Command 'model' must be one of: sonnet, opus, haiku, inherit. Got: '${MODEL_VAL}'. File: $FILE_PATH" >&2
  exit 2
fi

exit 0
