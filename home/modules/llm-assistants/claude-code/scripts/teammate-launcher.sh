#!/usr/bin/env bash

# ==============================================================================
# Claude Code Teammate Launcher
# ==============================================================================
# Agent-team teammates spawn via `tmux new-window` and exec Claude Code
# directly, bypassing the wrapper. Claude Code's env allowlist forwards
# ANTHROPIC_BASE_URL but not the auth token, so teammates would otherwise reach
# the API unauthenticated, and the wrapper's `--mcp-config` goes missing with
# it, leaving every server it declares unreachable. Referenced by the
# `processWrapper` setting.
# ==============================================================================

set -euo pipefail

source @profileLoader@

# Ahead of any subcommand, so the flag parses as a root-level global option.
exec "$1" @mcpFlag@ "${@:2}"
