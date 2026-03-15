#!/usr/bin/env bash

# ==============================================================================
# Enforce MCP Tool Usage
# ==============================================================================
# PreToolUse hook that blocks Bash commands which have MCP equivalents,
# forcing Claude Code to use the structured MCP tools instead.
#
# Blocks:
# - git subcommands with MCP Git equivalents (status, diff, add, etc.)
# - git -C (use MCP Git repo_path parameter)
# - gh CLI (use MCP GitHub tools)
# - Shell comment prefix (use Bash tool's description parameter)
#
# Allows through:
# - git subcommands without MCP equivalents (ls-files, blame, stash, etc.)
# - git commit --amend (no MCP equivalent)
# - git branch -d/-D, git reset --hard (destructive, no MCP equivalent)
# - All non-git, non-gh Bash commands
# ==============================================================================

COMMAND=$(jq -r '.tool_input.command')

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Block shell comment prefix — use the Bash tool's description parameter
if [[ "$COMMAND" =~ ^[[:space:]]*\# ]]; then
  deny "Do not prefix Bash commands with shell comments. Use the Bash tool's description parameter instead."
fi

# Block gh CLI — use MCP GitHub tools
if [[ "$COMMAND" =~ ^[[:space:]]*gh[[:space:]] ]]; then
  deny "Use MCP GitHub tools (mcp__GitHub__*) instead of the gh CLI."
fi

# Block git subcommands that have MCP equivalents
if [[ "$COMMAND" =~ ^[[:space:]]*git[[:space:]]+(.*) ]]; then
  REST="${BASH_REMATCH[1]}"

  # Block git -C — use MCP Git repo_path parameter
  if [[ "$REST" =~ ^-C[[:space:]] ]]; then
    deny "Use MCP Git tools with the repo_path parameter instead of git -C."
  fi

  SUBCMD="${REST%% *}"

  case "$SUBCMD" in
    add) deny "Use mcp__Git__git_add instead." ;;
    branch)
      # Allow git branch -d/-D (no MCP equivalent)
      if [[ "$COMMAND" =~ [[:space:]]-[dD]([[:space:]]|$) ]]; then
        exit 0
      fi
      deny "Use mcp__Git__git_branch or git_create_branch instead."
      ;;
    checkout) deny "Use mcp__Git__git_checkout or git_create_branch instead." ;;
    commit)
      # Allow git commit --amend (no MCP equivalent)
      if [[ "$COMMAND" =~ --amend ]]; then
        exit 0
      fi
      deny "Use mcp__Git__git_commit instead."
      ;;
    diff) deny "Use mcp__Git__git_diff / git_diff_unstaged / git_diff_staged instead." ;;
    log) deny "Use mcp__Git__git_log instead." ;;
    reset)
      # Allow git reset --hard (no MCP equivalent)
      if [[ "$COMMAND" =~ --hard ]]; then
        exit 0
      fi
      deny "Use mcp__Git__git_reset instead."
      ;;
    show) deny "Use mcp__Git__git_show instead." ;;
    status) deny "Use mcp__Git__git_status instead." ;;
  esac
fi

exit 0
