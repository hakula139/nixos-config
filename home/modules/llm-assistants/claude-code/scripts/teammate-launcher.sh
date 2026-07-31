#!/usr/bin/env bash

# ==============================================================================
# Claude Code Teammate Launcher
# ==============================================================================
# Agent-team teammates spawn via `tmux new-window` and exec Claude Code
# directly, bypassing the wrapper. Claude Code's env allowlist forwards
# ANTHROPIC_BASE_URL but not the auth token, so teammates would otherwise reach
# the API unauthenticated. Referenced by the `processWrapper` setting.
# ==============================================================================

set -euo pipefail

source @profileLoader@

exec "$@"
