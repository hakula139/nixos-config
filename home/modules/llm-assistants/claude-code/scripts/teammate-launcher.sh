#!/usr/bin/env bash

# ==================================================================================================
# Claude Code Teammate Launcher
# ==================================================================================================
# Agent-team teammates exec Claude Code through the `processWrapper` setting, bypassing the wrapper.
# Its env allowlist drops the auth token and no session flags are added, so load the profile here.
# ==================================================================================================

set -euo pipefail

claude_bin="$1"
shift

source @profileLoader@

exec "$claude_bin" "$@"
