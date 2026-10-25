#!/usr/bin/env bash

# ==================================================================================================
# Tunnel Hosts
# ==================================================================================================

set -euo pipefail

hosts_file=$1
gateway_host=$2

# The prefix also matches entries written under an earlier module name.
hosts_owner="# nixos-config:"

grep -vF "$hosts_owner" "$hosts_file" || [[ "$?" -eq 1 ]]
if [[ -n "$gateway_host" ]]; then
  printf '127.0.0.1 %s %s corp-tunnel\n' "$gateway_host" "$hosts_owner"
fi
