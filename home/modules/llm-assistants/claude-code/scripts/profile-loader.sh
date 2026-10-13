#!/usr/bin/env bash

# ==================================================================================================
# Claude Code Auth Profile Loader
# ==================================================================================================

set -euo pipefail

unset @profileEnvVars@

__claude_session_args=()

__claude_profile="@stateDir@/active-profile"
if [[ -f "$__claude_profile" ]]; then
  # shellcheck disable=SC1090  # dynamic profile path resolved at runtime
  . "$__claude_profile"
else
  echo "claude: no active auth profile at ${__claude_profile}" >&2
  exit 1
fi

while read -r __claude_command; do
  if [[ "${1-}" == "$__claude_command" ]]; then
    return
  fi
done <@utilityCommands@

set -- "${__claude_session_args[@]}" "@mcpFlag@" "$@"
