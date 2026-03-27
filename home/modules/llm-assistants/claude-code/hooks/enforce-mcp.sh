#!/usr/bin/env bash

# ==============================================================================
# Enforce MCP Tool Usage (PreToolUse)
# ==============================================================================
# PreToolUse hook that encourages MCP tool usage over Bash equivalents.
#
# Denies:
# - git -C (use MCP Git repo_path parameter)
#
# Hints (allows with suggestion):
# - git subcommands with MCP Git equivalents (status, diff, add, etc.)
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

hint() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Hint: shell comment prefix — use the Bash tool's description parameter
if [[ "$COMMAND" =~ ^[[:space:]]*\# ]]; then
  hint "Do not prefix Bash commands with shell comments. Use the Bash tool's description parameter instead."
fi

# Hint: gh CLI — use MCP GitHub tools
if [[ "$COMMAND" =~ ^[[:space:]]*gh[[:space:]] ]]; then
  hint "Use MCP GitHub tools (mcp__GitHub__*) instead of the gh CLI."
fi

# Hint: glab CLI — use MCP GitLab tools
if [[ "$COMMAND" =~ ^[[:space:]]*glab[[:space:]] ]]; then
  hint "Use MCP GitLab tools (mcp__GitLab__*) instead of the glab CLI."
fi

# Hint / deny git subcommands that have MCP equivalents
if [[ "$COMMAND" =~ ^[[:space:]]*git[[:space:]]+(.*) ]]; then
  REST="${BASH_REMATCH[1]}"

  # Deny git -C — use MCP Git repo_path parameter
  if [[ "$REST" =~ ^-C[[:space:]] ]]; then
    deny "Use MCP Git tools with the repo_path parameter instead of git -C."
  fi

  SUBCMD="${REST%% *}"

  case "$SUBCMD" in
    add) hint "Use mcp__Git__git_add instead." ;;
    branch)
      # Allow git branch -d/-D (no MCP equivalent)
      if [[ "$COMMAND" =~ [[:space:]]-[dD]([[:space:]]|$) ]]; then
        exit 0
      fi
      hint "Use mcp__Git__git_branch or git_create_branch instead."
      ;;
    checkout) hint "Use mcp__Git__git_checkout or git_create_branch instead." ;;
    commit)
      # Allow git commit --amend (no MCP equivalent)
      if [[ "$COMMAND" =~ --amend ]]; then
        exit 0
      fi
      hint "Use mcp__Git__git_commit instead."
      ;;
    diff) hint "Use mcp__Git__git_diff / git_diff_unstaged / git_diff_staged instead." ;;
    log) hint "Use mcp__Git__git_log instead." ;;
    reset)
      # Allow git reset --hard (no MCP equivalent)
      if [[ "$COMMAND" =~ --hard ]]; then
        exit 0
      fi
      hint "Use mcp__Git__git_reset instead."
      ;;
    show) hint "Use mcp__Git__git_show instead." ;;
    status) hint "Use mcp__Git__git_status instead." ;;
  esac
fi

exit 0
