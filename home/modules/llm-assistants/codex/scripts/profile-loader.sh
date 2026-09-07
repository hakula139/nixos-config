#!/usr/bin/env bash

set -euo pipefail

__codex_state_dir=@stateDir@
__codex_profile=@defaultProfile@
__codex_ca_file=@caFile@
if [[ -L "$__codex_state_dir/active-profile" ]]; then
  __codex_profile="$(basename "$(readlink "$__codex_state_dir/active-profile")" .config.toml)"
fi

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
  set -- --profile "$__codex_profile" "$@"
fi

# Codex adds this bundle to its system roots, including for native --profile calls.
if [[ -s "$__codex_ca_file" ]]; then
  export CODEX_CA_CERTIFICATE="$__codex_ca_file"
fi
