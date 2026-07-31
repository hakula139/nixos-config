#!/usr/bin/env bash

# ==============================================================================
# Claude Code Teammate Launcher
# ==============================================================================
# Agent-team teammates spawn via `tmux new-window`, which inherits the tmux
# server's environment instead of the parent pane's. Claude Code re-injects
# only its own allowlist, which carries ANTHROPIC_BASE_URL but omits the auth
# token, CA bundle and model overrides, so teammates reach the gateway
# unauthenticated. CLAUDE_CODE_PROCESS_WRAPPER points here to restore the
# active auth profile before handing off to Claude Code.
# ==============================================================================

set -euo pipefail

source @profileLoader@

exec "$@"
