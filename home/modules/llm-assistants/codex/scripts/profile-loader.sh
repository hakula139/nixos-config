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

# app-server rejects --profile. Supply the active profile as config overrides.
if [[ ${1:-} == app-server ]]; then
  mapfile -d '' __codex_args < <(@profileOverrides@ "$__codex_profile")
  # mapfile reports success even when the producer died partway through.
  wait "$!"
  if [[ ${#__codex_args[@]} -eq 0 ]]; then
    echo "codex: no app-server overrides from $__codex_profile" >&2
    exit 1
  fi
else
  __codex_args=(--profile "$(basename "$(readlink "$__codex_profile")" .config.toml)")
fi

set -- "${__codex_args[@]}" "$@"
