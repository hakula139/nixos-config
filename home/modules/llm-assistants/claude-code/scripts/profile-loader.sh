#!/usr/bin/env bash

# ==================================================================================================
# Claude Code Auth Profile Loader
# ==================================================================================================

set -euo pipefail

unset @profileEnvVars@

__claude_profile="@stateDir@/active-profile"
if [[ -f "$__claude_profile/env.sh" ]]; then
  # shellcheck disable=SC1091  # dynamic profile path resolved at runtime
  . "$__claude_profile/env.sh"
else
  echo "claude: no active auth profile at ${__claude_profile}" >&2
  exit 1
fi
