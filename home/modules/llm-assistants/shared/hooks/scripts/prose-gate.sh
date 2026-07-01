#!/usr/bin/env bash

# ==============================================================================
# Prose Style Gate (PostToolUse)
# ==============================================================================
# Judges the prose the assistant wrote via a headless `claude -p` call, emitting
# additionalContext (non-halting) on a violation. Fails open on any error.
# ==============================================================================

# The judge subprocess would otherwise re-trigger this hook.
if [[ -n "${CLAUDE_PROSE_GATE_ACTIVE:-}" ]]; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  Write) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty') ;;
  Edit) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty') ;;
  *) exit 0 ;;
esac

[[ -n "${CONTENT//[[:space:]]/}" && ${#CONTENT} -ge 12 ]] || exit 0

PROMPT_FILE="@promptFile@"
[[ -r "$PROMPT_FILE" ]] || exit 0

# --bare skips hooks / LSP / plugins / MCP; the haiku alias resolves through the
# active profile's default model.
RAW=$(cd /tmp && CLAUDE_PROSE_GATE_ACTIVE=1 timeout 60 claude -p "$CONTENT" \
  --bare \
  --system-prompt-file "$PROMPT_FILE" \
  --model haiku \
  --output-format json \
  2>/dev/null)

# The verdict JSON is under .result, sometimes fenced in ```json.
VERDICT=$(printf '%s' "$RAW" | jq -r '.result // empty' 2>/dev/null \
  | sed -e 's/^```[a-z]*//' -e 's/```$//' | tr -d '\n')
[[ "$(printf '%s' "$VERDICT" | jq -r '.ok' 2>/dev/null)" == "false" ]] || exit 0

REASON=$(printf '%s' "$VERDICT" | jq -r '.reason // "prose style violation"' 2>/dev/null)

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("Prose style gate flagged the text you just wrote. Fix it in place, then continue. " + $reason)
  }
}'
