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
  # Added lines only: context lines are text the assistant did not write.
  apply_patch) CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' \
    | sed -n -E 's/^\+(.*)$/\1/p') ;;
  mcp__*) CONTENT=$(printf '%s' "$INPUT" \
    | jq -r '.tool_input.message // .tool_input.description // .tool_input.body // .tool_input.note // .tool_input.content // .tool_input.new_content // empty') ;;
  *) exit 0 ;;
esac

[[ -n "${CONTENT//[[:space:]]/}" && ${#CONTENT} -ge 12 ]] || exit 0

PROMPT_FILE="@promptFile@"
[[ -r "$PROMPT_FILE" ]] || exit 0

# Pre-filter: skip the ~12.5s judge when vale's parser for this file type finds
# no prose or comment in the payload. Empty output means pure code. An absent
# vale, an unreadable config, or a vale error all fall through to the judge, so
# the gate never silently stops checking.
VALE="@vale@"
VALE_CONFIG="@valeConfig@"
if [[ -x "$VALE" && -r "$VALE_CONFIG" ]]; then
  case "$TOOL_NAME" in
    apply_patch) FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' \
      | sed -n -E 's/^\*\*\* (Add|Update) File: //p' | head -1) ;;
    *) FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty') ;;
  esac
  # vale selects its comment parser from the extension. Prose fields from MCP
  # tools and unknown extensions fall back to .md, which treats all of it as
  # prose and so never skips.
  case "$FILE_PATH" in
    *.*) VALE_EXT=".${FILE_PATH##*.}" ;;
    *) VALE_EXT=".md" ;;
  esac
  # vale has no Nix parser, and Python's comment and string syntax matches.
  [[ "$VALE_EXT" == ".nix" ]] && VALE_EXT=".py"

  if VALE_OUT=$(printf '%s' "$CONTENT" \
    | timeout 10 "$VALE" --config="$VALE_CONFIG" --ext="$VALE_EXT" --output=line 2>/dev/null); then
    [[ -n "$VALE_OUT" ]] || exit 0
  fi
fi

RAW=$(cd /tmp && CLAUDE_PROSE_GATE_ACTIVE=1 timeout 25 claude -p "$CONTENT" \
  --bare \
  --system-prompt-file "$PROMPT_FILE" \
  --model sonnet \
  --output-format json \
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
