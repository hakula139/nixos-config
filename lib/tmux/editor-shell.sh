#!/bin/sh

# ==================================================================================================
# Editor tmux Shell
# ==================================================================================================

if command -v tmux >/dev/null 2>&1 && [ -z "${TMUX:-}" ]; then
  session_name=$(printf '%s\n' "${PWD##*/}" | LC_ALL=en_US.UTF-8 sed 's/[^[:alnum:]]/-/g')
  exec tmux new-session -A -s "$session_name"
else
  exec "${SHELL:-/bin/sh}" -l
fi
