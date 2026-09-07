#!/usr/bin/env bash

# ==============================================================================
# Codex Auth Profile Loader
# ==============================================================================

set -euo pipefail

__codex_profile=@stateDir@/active-profile
__codex_ca_file=@caFile@

# Explicit CLI profiles and config-free hook calls retain their own selection.
__codex_add_profile=true
for __codex_arg in "$@"; do
  case "$__codex_arg" in
    --profile | --profile=* | -p | -p?* | --ignore-user-config)
      __codex_add_profile=false
      break
      ;;
    --)
      break
      ;;
  esac
done
if [[ "$__codex_add_profile" == true ]]; then
  if [[ -f "$__codex_profile" ]]; then
    set -- --profile "$(basename "$(readlink "$__codex_profile")" .config.toml)" "$@"
  else
    echo "codex: no active auth profile at ${__codex_profile}" >&2
  fi
fi

# Codex adds this bundle to its system roots, including for native --profile calls.
if [[ -s "$__codex_ca_file" ]]; then
  export CODEX_CA_CERTIFICATE="$__codex_ca_file"
fi
