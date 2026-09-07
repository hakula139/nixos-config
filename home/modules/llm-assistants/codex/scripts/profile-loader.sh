#!/usr/bin/env bash

# ==============================================================================
# Codex Auth Profile Loader
# ==============================================================================

set -euo pipefail

@caEnv@

# Explicit CLI profiles and config-free hook calls retain their own selection.
for __codex_arg in "$@"; do
  case "$__codex_arg" in
    --profile | --profile=* | -p | -p?* | --ignore-user-config)
      return
      ;;
    --)
      break
      ;;
  esac
done

__codex_profile="@stateDir@/active-profile"
set -- --profile "$(basename "$(readlink "$__codex_profile")" .config.toml)" "$@"
