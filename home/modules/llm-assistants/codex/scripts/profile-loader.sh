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

# `codex app-server` accepts a profile only as startup config overrides, and
# rejects `--profile` outright. Dropping the profile there instead would leave an
# ACP session on the base config, so on a work host it would lose the gateway
# provider and its credentials. Matching only the leading subcommand keeps
# `codex exec app-server` reading as the prompt it is.
if [[ ${1:-} == app-server ]]; then
  mapfile -d '' __codex_overrides < <(@profileOverrides@ "$__codex_profile")
  # mapfile reports success even when the producer died partway through.
  wait "$!"
  # Every profile sets at least a model, so an empty result means the active
  # profile is missing or unreadable rather than genuinely empty.
  if [[ ${#__codex_overrides[@]} -eq 0 ]]; then
    echo "codex: no app-server overrides from $__codex_profile" >&2
    exit 1
  fi
  set -- "${__codex_overrides[@]}" "$@"
  return
fi

set -- --profile "$(basename "$(readlink "$__codex_profile")" .config.toml)" "$@"
