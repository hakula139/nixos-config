#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Network Access Tracker
# ==============================================================================
# PostToolUse hook that logs every tool invocation's known network destinations.
#
# Output: appends JSONL to ~/.claude/network-tracker/<date>.jsonl
# ==============================================================================

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')

[[ -z "$TOOL_NAME" ]] && exit 0

LOG_DIR="$HOME/.claude/network-tracker"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m-%d).jsonl"

# Strip scheme and path from URLs, leaving just the hostname
url_to_host() { sed -E 's|^https?://||; s|/.*||'; }

DOMAINS=""
TOOL_TYPE=""

case "$TOOL_NAME" in
  # Extract domain from the target URL
  WebFetch)
    TOOL_TYPE="web"
    DOMAINS=$(printf '%s' "$INPUT" | jq -r '.tool_input.url // empty' | url_to_host)
    ;;
  # WebSearch runs server-side at Anthropic (no outbound request from client)
  WebSearch)
    TOOL_TYPE="web"
    DOMAINS="api.anthropic.com(search)"
    ;;
  # Extract domains from any URL in the command string
  Bash)
    TOOL_TYPE="bash"
    COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
    DOMAINS=$(printf '%s' "$COMMAND" | grep -oE 'https?://[^[:space:]"'"'"'|;)]+' 2>/dev/null \
      | url_to_host | sort -u | tr '\n' ' ' || true)
    [[ -z "${DOMAINS// /}" ]] && exit 0
    ;;
  # MCP servers — static domain mapping (update when adding new servers)
  mcp__Codex__*)
    TOOL_TYPE="mcp"
    DOMAINS="api.openai.com"
    ;;
  mcp__DeepWiki__*)
    TOOL_TYPE="mcp"
    DOMAINS="mcp.deepwiki.com"
    ;;
  # Fetcher targets user-specified URLs, extract from tool input
  mcp__Fetcher__*)
    TOOL_TYPE="mcp"
    DOMAINS=$(printf '%s' "$INPUT" | jq -r '
      .tool_input.url // .tool_input.urls // empty |
      if type == "array" then .[] else . end
    ' 2>/dev/null | url_to_host | sort -u | tr '\n' ' ')
    [[ -z "${DOMAINS// /}" ]] && exit 0
    ;;
  mcp__GitHub__*)
    TOOL_TYPE="mcp"
    DOMAINS="api.github.com"
    ;;
  # GitLab host is configured per-environment via glab, not necessarily gitlab.com
  mcp__GitLab__*)
    TOOL_TYPE="mcp"
    DOMAINS=$(glab config get host 2>/dev/null || echo "gitlab.com")
    ;;
  mcp__NixOS__*)
    TOOL_TYPE="mcp"
    DOMAINS="search.nixos.org"
    ;;
  mcp__plugin_context7*)
    TOOL_TYPE="mcp"
    DOMAINS="api.context7.com"
    ;;
  # Local-only tools and unknown tools — no network access
  *) exit 0 ;;
esac

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)

printf '%s' "$INPUT" | jq -c \
  --arg ts "$TIMESTAMP" \
  --arg domains "$DOMAINS" \
  --arg tool_type "$TOOL_TYPE" \
  --arg session "$SESSION_ID" \
  '{
    ts: $ts,
    tool: .tool_name,
    tool_type: $tool_type,
    domains: ($domains | split(" ") | map(select(length > 0))),
    session_id: $session,
    detail: (
      if .tool_name == "WebFetch" then .tool_input.url
      elif .tool_name == "WebSearch" then .tool_input.query
      elif .tool_name == "Bash" then (.tool_input.command | split("\n") | first)
      elif (.tool_name | startswith("mcp__")) then
        (.tool_name | split("__") | .[1]) + "/" + (.tool_name | split("__") | .[2:] | join("__"))
      else null
      end
    )
  }' >>"$LOG_FILE"

exit 0
