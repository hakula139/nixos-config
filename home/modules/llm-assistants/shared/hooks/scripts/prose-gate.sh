#!/usr/bin/env bash

# ==============================================================================
# Prose Style Gate (PostToolUse)
# ==============================================================================
# Judges the prose the assistant wrote via a headless `claude -p` call, emitting
# additionalContext (non-halting) on a violation. Fails open on any error.
# ==============================================================================

# `-e` is omitted: the checks below intentionally fall through to `exit 0`.
set -uo pipefail

# The judge subprocess would otherwise re-trigger this hook.
if [[ -n "${CLAUDE_PROSE_GATE_ACTIVE:-}" ]]; then
  exit 0
fi

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  Write) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty') ;;
  Edit) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty') ;;
  apply_patch) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty') ;;
  mcp__*) CONTENT=$(printf '%s' "$INPUT" \
    | jq -r '.tool_input.message // .tool_input.description // .tool_input.body // .tool_input.note // .tool_input.content // .tool_input.new_content // empty') ;;
  *) exit 0 ;;
esac

[[ -n "${CONTENT//[[:space:]]/}" && ${#CONTENT} -ge 12 ]] || exit 0

PROMPT_FILE="@promptFile@"
[[ -r "$PROMPT_FILE" ]] || exit 0

# `--` is required: content starting with `-`, such as a Markdown bullet, is
# otherwise parsed as an unknown option and the judge never sees it.
RAW=$(cd /tmp && CLAUDE_PROSE_GATE_ACTIVE=1 timeout "@judgeTimeout@" claude -p \
  --bare \
  --system-prompt-file "$PROMPT_FILE" \
  --model sonnet \
  --output-format json \
  -- "$CONTENT" \
  2>/dev/null)

# The verdict JSON is under .result, sometimes wrapped in a code fence or
# backticks. Extract the outermost {...} to strip any such wrapper.
VERDICT=$(printf '%s' "$RAW" | jq -r '.result // empty' 2>/dev/null \
  | tr -d '\n' | grep -oE '\{.*\}')
[[ "$(printf '%s' "$VERDICT" | jq -r '.ok' 2>/dev/null)" == "false" ]] || exit 0

REASON=$(printf '%s' "$VERDICT" | jq -r '.reason // "prose style violation"' 2>/dev/null)

jq -n --arg reason "$REASON" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("Prose style gate flagged the text you just wrote. Fix it in place, then continue. " + $reason)
  }
}'
