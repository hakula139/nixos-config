#!/usr/bin/env nu

# ==================================================================================================
# Tunnel Hosts
# ==================================================================================================

# The prefix also matches entries written under an earlier module name.
const HOSTS_OWNER = "# nixos-config:"

# Rewrite the owned mappings, removing them when the hostname is empty.
def main [hosts_file: path, hostname: string] {
  # Owned lines, including their trailing newline when present.
  let pattern = ('^.*' + $HOSTS_OWNER + '.*\n?')
  let retained = (
    open --raw $hosts_file
    | default ""
    | str replace --all --multiline --regex $pattern ""
  )

  print --no-newline $retained
  if $hostname != "" {
    if ($retained | is-not-empty) and not ($retained | str ends-with (char nl)) {
      print ""
    }
    print $"127.0.0.1 ($hostname) ($HOSTS_OWNER) corp-tunnel"
  }
}
