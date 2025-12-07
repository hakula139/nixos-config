# ============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ============================================================================

let
  keys = import ./keys.nix;
  publicKeys = builtins.attrValues keys.users ++ builtins.attrValues keys.hosts;
in
{
  "cloudflare-credentials.age".publicKeys = publicKeys;
  "xray-config.json.age".publicKeys = publicKeys;
  "clash-users.json.age".publicKeys = publicKeys;
}
