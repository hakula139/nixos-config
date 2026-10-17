#!/usr/bin/env bash

# ==================================================================================================
# tmux Wrapper
# ==================================================================================================
# A tmux server hands the environment it starts with to every pane, so it must not start inside a
# dev shell. direnv records its changes, which `direnv exec /` reverts exactly. A Nix shell keeps
# no such record, so inside one tmux may reach a running server but never start a new one.
# ==================================================================================================

set -euo pipefail

if [[ -n "${DIRENV_DIFF:-}" ]]; then
  exec @direnv@ exec / "$0" "$@"
fi

if [[ -z "${IN_NIX_SHELL:-}" ]]; then
  exec @tmux@ "$@"
fi

socket=()
while getopts ':c:f:L:S:T:' opt; do
  case "$opt" in
    L | S) socket=("-$opt" "$OPTARG") ;;
    *) ;;
  esac
done

status=0
@tmux@ -N "$@" || status=$?
if ((status != 0)) && ! @tmux@ "${socket[@]}" -N has-session 2>/dev/null; then
  echo "tmux: not starting a server inside a Nix shell, whose environment every pane would inherit" >&2
fi
exit "$status"
