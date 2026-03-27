#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# WakaTime Heartbeat for AI-Generated Code (PostToolUse)
# ==============================================================================
# PostToolUse hook that sends a file-level WakaTime heartbeat with
# --ai-line-changes for each Edit or Write tool invocation.
#
# This replaces the claude-code-wakatime plugin's app-level heartbeats,
# which lack language detection (reported as "Other") and rarely include
# AI line attribution.
# ==============================================================================

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name')
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0

# Resolve platform-specific wakatime-cli binary
WAKATIME_CLI="$HOME/.wakatime/wakatime-cli-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
[[ -x "$WAKATIME_CLI" ]] || exit 0

# Calculate net line changes from the tool input
case "$TOOL_NAME" in
  Edit)
    LINE_CHANGES=$(printf '%s' "$INPUT" | jq '
      ((.tool_input.new_string // "") | split("\n") | length)
      - ((.tool_input.old_string // "") | split("\n") | length)
    ')
    ;;
  Write)
    LINE_CHANGES=$(printf '%s' "$INPUT" | jq '(.tool_input.content // "") | split("\n") | length')
    ;;
  *)
    exit 0
    ;;
esac

PROJECT_FOLDER=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')

ARGS=(
  --entity "$FILE_PATH"
  --entity-type file
  --write
  --category "ai coding"
  --plugin "claude-code-hook/1.0"
  --ai-line-changes "$LINE_CHANGES"
)
[[ -n "$PROJECT_FOLDER" ]] && ARGS+=(--project-folder "$PROJECT_FOLDER")

"$WAKATIME_CLI" "${ARGS[@]}" >/dev/null 2>&1 || true
