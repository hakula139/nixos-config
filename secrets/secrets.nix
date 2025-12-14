# ==============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ==============================================================================

let
  keys = import ./keys.nix;
  publicKeys = builtins.attrValues keys.users ++ builtins.attrValues keys.hosts;
in
{
  "cachix-auth-token.age".publicKeys = publicKeys;
  "clash-users.json.age".publicKeys = publicKeys;
  "cloudflare-credentials.age".publicKeys = publicKeys;
  "qq-smtp-authcode.age".publicKeys = publicKeys;
  "xray-config.json.age".publicKeys = publicKeys;
}
