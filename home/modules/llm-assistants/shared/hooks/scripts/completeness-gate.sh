#!/usr/bin/env bash

# ==============================================================================
# Completeness Gate (Stop)
# ==============================================================================
# Codex port of Claude Code's `prompt`-type Stop gate. Codex runs only `command`
# handlers, so this reconstructs the transcript, substitutes it into the same
# shared prompt, calls its own judge, and emits {"decision":"block"} to inject
# the reason as a continuation prompt. Fails open on any error.
# ==============================================================================

set -uo pipefail

INPUT=$(cat)

# Codex sets this after a block, so the gate judges a turn at most once.
if [[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false')" == "true" ]]; then
  exit 0
fi

PROMPT_FILE="@promptFile@"
[[ -r "$PROMPT_FILE" ]] || exit 0

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')
[[ -r "$TRANSCRIPT" ]] || exit 0

CONTEXT=$(jq -rs --argjson turns "@turns@" '
  [ .[]
    | select(.type == "response_item")
    | .payload
    | select(.type == "message" and (.role == "user" or .role == "assistant"))
    | { role, text: ([.content[]? | .text // empty] | join("\n")) }
    | select(.text != "")
  ]
  | .[-$turns:]
  | map("<" + .role + ">\n" + .text + "\n</" + .role + ">")
  | join("\n\n")
' "$TRANSCRIPT" 2>/dev/null)

[[ -n "${CONTEXT//[[:space:]]/}" ]] || exit 0

# `awk` against ENVIRON so `&`, `\`, and `|` in the transcript survive intact.
PROMPT=$(CONTEXT="$CONTEXT" awk '
  index($0, "$ARGUMENTS") { print ENVIRON["CONTEXT"]; next }
  { print }
' "$PROMPT_FILE")

VERDICT=$(cd /tmp && timeout 30 claude -p "$PROMPT" \
  --bare \
  --system-prompt 'Respond with EXACTLY ONE LINE of compact JSON and nothing else, no markdown and no code fence: {"ok":true} or {"ok":false,"reason":"<the specific unfinished or misreported item>"}. Never place a literal double-quote inside the reason.' \
  --model sonnet \
  --output-format json \
  2>/dev/null \
  | jq -r '.result // empty' 2>/dev/null \
  | tr -d '\n' | grep -oE '\{.*\}')

[[ "$(printf '%s' "$VERDICT" | jq -r '.ok' 2>/dev/null)" == "false" ]] || exit 0

# Codex warns and ignores the block when the reason is empty.
REASON=$(printf '%s' "$VERDICT" | jq -r '.reason // empty' 2>/dev/null)
[[ -n "${REASON//[[:space:]]/}" ]] || exit 0

jq -n --arg reason "$REASON" '{
  decision: "block",
  reason: ("Completeness gate: requested work looks unfinished. " + $reason
    + " Finish it, or ask me to decide if you are blocked.")
}'
