# ==============================================================================
# Enforce MCP Tool Usage (PreToolUse)
# ==============================================================================
# PreToolUse hook that encourages MCP tool usage over Bash equivalents.
#
# Denies:
# - git -C (use MCP Git repo_path parameter)
#
# Hints:
# - git subcommands with MCP Git equivalents (status, diff, add, etc.)
# - gh CLI (use MCP GitHub tools)
# - glab CLI (use MCP GitLab tools)
# - Shell comment prefix (use the tool description / surrounding text)
#
# Allows through:
# - git subcommands without MCP equivalents (ls-files, blame, stash, etc.)
# - git branch -d/-D, git commit --amend, git reset --hard
# - All non-git, non-gh, non-glab Bash commands
#
# Claude Code accepts a PreToolUse "allow" decision with a reason as a hint.
# Codex currently parses but does not support "allow" / "ask" PreToolUse
# decisions, so Codex gets the same hint through systemMessage instead.
# ==============================================================================

COMMAND=$(jq -r '.tool_input.command // empty')
HINT_MODE="${HAKULA_HOOK_HINT_MODE:-system-message}"

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
  case "$HINT_MODE" in
    permission-allow)
      jq -n --arg reason "$1" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "allow",
          permissionDecisionReason: $reason
        }
      }'
      ;;
    *)
      jq -n --arg reason "$1" '{
        systemMessage: $reason
      }'
      ;;
  esac
  exit 0
}

# Hint: shell comment prefix; describe the command outside the shell command.
if [[ "$COMMAND" =~ ^[[:space:]]*\# ]]; then
  hint "Do not prefix Bash commands with shell comments. Describe the command outside the shell command instead."
fi

# Hint: gh CLI; use MCP GitHub tools.
if [[ "$COMMAND" =~ ^[[:space:]]*gh[[:space:]] ]]; then
  hint "Use MCP GitHub tools instead of the gh CLI when an equivalent tool is available."
fi

# Hint: glab CLI; use MCP GitLab tools.
if [[ "$COMMAND" =~ ^[[:space:]]*glab[[:space:]] ]]; then
  hint "Use MCP GitLab tools instead of the glab CLI when an equivalent tool is available."
fi

# Hint / deny git subcommands that have MCP equivalents.
if [[ "$COMMAND" =~ ^[[:space:]]*git[[:space:]]+(.*) ]]; then
  REST="${BASH_REMATCH[1]}"

  # Deny git -C; use MCP Git repo_path parameter.
  if [[ "$REST" =~ ^-C[[:space:]] ]]; then
    deny "Use MCP Git tools with the repo_path parameter instead of git -C."
  fi

  SUBCMD="${REST%% *}"

  case "$SUBCMD" in
    add) hint "Use mcp__Git__git_add instead." ;;
    branch)
      # Allow git branch -d/-D (no MCP equivalent).
      if [[ "$COMMAND" =~ [[:space:]]-[dD]([[:space:]]|$) ]]; then
        exit 0
      fi
      hint "Use mcp__Git__git_branch or mcp__Git__git_create_branch instead."
      ;;
    checkout) hint "Use mcp__Git__git_checkout or mcp__Git__git_create_branch instead." ;;
    commit)
      # Allow git commit --amend (no MCP equivalent).
      if [[ "$COMMAND" =~ --amend ]]; then
        exit 0
      fi
      hint "Use mcp__Git__git_commit instead."
      ;;
    diff) hint "Use mcp__Git__git_diff, mcp__Git__git_diff_unstaged, or mcp__Git__git_diff_staged instead." ;;
    log) hint "Use mcp__Git__git_log instead." ;;
    reset)
      # Allow git reset --hard (no MCP equivalent).
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
