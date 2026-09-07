#!/usr/bin/env bash

# ==============================================================================
# Claude Code Auth Profile Loader
# ==============================================================================

@unsetVars@

__claude_profile="@stateDir@/active-profile"
if [[ -f "$__claude_profile" ]]; then
  # shellcheck disable=SC1090  # dynamic profile path resolved at runtime
  . "$__claude_profile"
else
  echo "claude: no active auth profile at ${__claude_profile}" >&2
fi
