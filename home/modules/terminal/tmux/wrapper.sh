#!/usr/bin/env bash

# ==================================================================================================
# tmux Wrapper
# ==================================================================================================
# tmux panes are environment-neutral: each directory's dev shell comes from direnv, so a client
# never passes on a dev shell. A new server would hand its environment to every pane, and a client
# outside a session lends its PATH to the panes it creates. direnv's changes are reverted exactly
# with `direnv exec /`. A Nix shell records no such diff, so inside one the client borrows the
# server's PATH and never starts a server.
#
# A pane command started from a dev shell, such as `tmux new-window 'cargo run'`, therefore runs
# without it, the same as an interactive pane shell. Run it through `direnv exec . <cmd>`, or let
# the pane shell's direnv hook load the dev shell in an allowed directory.
# ==================================================================================================

set -euo pipefail

if [[ -n "${DIRENV_DIFF:-}" ]]; then
  exec @direnv@ exec / "$0" "$@"
fi

if [[ -z "${IN_NIX_SHELL:-}" && -z "${NIX_BUILD_TOP:-}" ]]; then
  exec @tmux@ "$@"
fi

socket=()
while getopts ':c:f:L:S:T:V' opt; do
  case "$opt" in
    L | S) socket+=("-$opt" "$OPTARG") ;;
    V) exec @tmux@ "$@" ;;
    *) ;;
  esac
done
command="${!OPTIND:-new-session}"

if server_path="$(@tmux@ "${socket[@]}" -N show-environment -g PATH 2>/dev/null)"; then
  PATH="${server_path#PATH=}" exec @tmux@ -N "$@"
fi

case "$command" in
  new | new-s* | start | start-s*)
    echo "tmux: no server is running, and none is started inside a Nix shell." >&2
    echo "Start tmux outside the Nix shell, or run: env -u IN_NIX_SHELL -u NIX_BUILD_TOP tmux" >&2
    exit 1
    ;;
esac

exec @tmux@ -N "$@"
