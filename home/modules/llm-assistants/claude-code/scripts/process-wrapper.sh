#!/usr/bin/env bash

# ==================================================================================================
# Claude Code Process Wrapper
# ==================================================================================================
# Background sessions, their workers, and agent-team teammates start through the `processWrapper`
# setting, bypassing the wrapper, and Claude Code's env allowlist drops the auth token, so load the
# profile here. Claude Code forwards the session flags itself and rejects them on internal commands.
# ==================================================================================================

set -euo pipefail

source @profileLoader@

exec "$@"
