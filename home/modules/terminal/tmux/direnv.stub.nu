#!/usr/bin/env nu

# ==================================================================================================
# direnv Stub
# ==================================================================================================
# Stands in for `direnv exec /` in the wrapper tests. Each call appends its arguments to
# `STUB_LOG`, then runs the command without the direnv-injected `DIRENV_DIFF` and `IN_NIX_SHELL`,
# as reverting a nix-direnv shell does.
# ==================================================================================================

def --wrapped main [...args: string] {
  {tool: direnv, args: $args} | to json --raw | $"($in)\n" | save --append $env.STUB_LOG

  hide-env DIRENV_DIFF
  hide-env --ignore-errors IN_NIX_SHELL
  exec bash ...($args | skip 2)
}
