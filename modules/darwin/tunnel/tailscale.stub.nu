#!/usr/bin/env nu

# ==================================================================================================
# Tailscale Stub
# ==================================================================================================

def --wrapped main [...args: string] {
  {
    command: tailscale
    args: $args
  }
  | to json --raw
  | $"($in)\n"
  | save --append $env.STUB_LOG

  {BackendState: $env.STUB_TAILSCALE_STATE} | to json --raw | print
}
