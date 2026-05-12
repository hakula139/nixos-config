command=$(jq -r '.tool_input.command // empty')
hint_mode="${HAKULA_HOOK_HINT_MODE:-system-message}"

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
  case "$hint_mode" in
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

if [[ "$command" =~ ^[[:space:]]*\# ]]; then
  hint "Do not prefix Bash commands with shell comments. Describe the command outside the shell command instead."
fi

if [[ "$command" =~ ^[[:space:]]*gh[[:space:]] ]]; then
  hint "Use MCP GitHub tools instead of the gh CLI when an equivalent tool is available."
fi

if [[ "$command" =~ ^[[:space:]]*glab[[:space:]] ]]; then
  hint "Use MCP GitLab tools instead of the glab CLI when an equivalent tool is available."
fi

if [[ "$command" =~ ^[[:space:]]*git[[:space:]]+(.*) ]]; then
  rest="${BASH_REMATCH[1]}"

  if [[ "$rest" =~ ^-C[[:space:]] ]]; then
    deny "Use MCP Git tools with the repo_path parameter instead of git -C."
  fi

  subcmd="${rest%% *}"

  case "$subcmd" in
    add) hint "Use mcp__Git__git_add instead." ;;
    branch)
      if [[ "$command" =~ [[:space:]]-[dD]([[:space:]]|$) ]]; then
        exit 0
      fi
      hint "Use mcp__Git__git_branch or mcp__Git__git_create_branch instead."
      ;;
    checkout) hint "Use mcp__Git__git_checkout or mcp__Git__git_create_branch instead." ;;
    diff) hint "Use mcp__Git__git_diff, mcp__Git__git_diff_unstaged, or mcp__Git__git_diff_staged instead." ;;
    log) hint "Use mcp__Git__git_log instead." ;;
    reset)
      if [[ "$command" =~ --hard ]]; then
        exit 0
      fi
      hint "Use mcp__Git__git_reset instead."
      ;;
    show) hint "Use mcp__Git__git_show instead." ;;
    status) hint "Use mcp__Git__git_status instead." ;;
  esac
fi

exit 0
