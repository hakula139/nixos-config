#!/bin/sh

# ==================================================================================================
# Editor tmux Shell
# ==================================================================================================

if command -v tmux >/dev/null 2>&1 && [ -z "${TMUX:-}" ]; then
  session_name=$(printf '%s' "${PWD##*/}" | LC_ALL=C tr -c '[:alnum:]' '[-*]')
  exec tmux new-session -A -s "$session_name"
else
  exec "${SHELL:-/bin/sh}" -l
fi
