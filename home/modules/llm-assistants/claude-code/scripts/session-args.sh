#!/usr/bin/env bash

# ==================================================================================================
# Claude Code Session Arguments
# ==================================================================================================
# Subcommands, hidden ones included, are bare lowercase words that reject or misread session flags,
# so a one-word prompt needs a leading `--`. `agents` forwards them to the sessions it dispatches.
# ==================================================================================================

# shellcheck disable=SC2154  # set by the profile loader
if [[ "${1-}" == agents || ! "${1-}" =~ ^[a-z][a-z-]*$ ]]; then
  set -- "--settings=${__claude_settings}" "@mcpFlag@" "$@"
fi
