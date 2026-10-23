#!/usr/bin/env bash

# ==================================================================================================
# oxide-code Auth Profile Loader
# ==================================================================================================

set -euo pipefail

unset @profileEnvVars@

__ox_profile="@stateDir@/active-profile"
if [[ -f "$__ox_profile" ]]; then
  # shellcheck disable=SC1090  # dynamic profile path resolved at runtime
  . "$__ox_profile"
else
  echo "ox: no active auth profile at ${__ox_profile}" >&2
  exit 1
fi
