#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# WakaTime Heartbeat for AI-Generated Code (PostToolUse)
# ==============================================================================
# PostToolUse hook that asks wakatime-cli to parse AI assistant transcripts and
# send the resulting file-level AI heartbeats.
#
# This mirrors the current claude-code-wakatime plugin behavior without letting
# the hook download or install its own CLI binary.
# ==============================================================================

INPUT=$(cat)
readonly PLUGIN_NAME="@pluginName@"

if ! wakatime-cli --help 2>/dev/null | grep -q -- '--sync-ai-activity'; then
  exit 0
fi

PROJECT_FOLDER=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
STATE_ID=$(
  printf '%s' "$INPUT" \
    | jq -r '.transcript_path // .session_id // ."thread-id" // .thread_id // .cwd // "unknown"' 2>/dev/null \
    || true
)

WAKATIME_HOME_DIR="${WAKATIME_HOME:-${HOME:-}}"
[[ -n "$WAKATIME_HOME_DIR" ]] || exit 0

STATE_DIR="$WAKATIME_HOME_DIR/.wakatime/llm-assistants"
STATE_ID=$(printf '%s' "$STATE_ID" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_' | cut -c1-160)
PLUGIN_ID=$(printf '%s' "$PLUGIN_NAME" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_' | cut -c1-80)
STATE_FILE="$STATE_DIR/${PLUGIN_ID}-${STATE_ID:-unknown}.wakatime"

NOW=$(date +%s)
if [[ -r "$STATE_FILE" ]]; then
  LAST=$(<"$STATE_FILE")
  if [[ "$LAST" =~ ^[0-9]+$ ]] && ((NOW - LAST < 60)); then
    exit 0
  fi
fi

ARGS=(
  --sync-ai-activity
  --plugin "$PLUGIN_NAME"
)
[[ -n "$PROJECT_FOLDER" ]] && ARGS+=(--project-folder "$PROJECT_FOLDER")

mkdir -p "$STATE_DIR"
timeout "@toolTimeout@" wakatime-cli "${ARGS[@]}" >/dev/null 2>&1 || true
printf '%s\n' "$NOW" >"$STATE_FILE"
