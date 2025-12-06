# ============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ============================================================================

let
  keys = import ./keys.nix;

  allUsers = builtins.attrValues keys.users;
  allHosts = builtins.attrValues keys.hosts;
in
{
  "cloudflare-credentials.age".publicKeys = allUsers ++ allHosts;
}
