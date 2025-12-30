# ==============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ==============================================================================

let
  keys = import ./keys.nix;
  allUserKeys = builtins.attrValues keys.users;
  allHostKeys = builtins.attrValues keys.hosts;
  sharedKeys = allUserKeys ++ allHostKeys;
in
{
  # ----------------------------------------------------------------------------
  # Shared (multi-host)
  # ----------------------------------------------------------------------------
  "shared/aria2-rpc-secret.age".publicKeys = sharedKeys;
  "shared/backup-env.age".publicKeys = sharedKeys;
  "shared/backup-restic-password.age".publicKeys = sharedKeys;
  "shared/brave-api-key.age".publicKeys = sharedKeys;
  "shared/cachix-auth-token.age".publicKeys = sharedKeys;
  "shared/clash-users.json.age".publicKeys = sharedKeys;
  "shared/cloudflare-credentials.age".publicKeys = sharedKeys;
  "shared/dockerhub-token.age".publicKeys = sharedKeys;
  "shared/piclist-config.json.age".publicKeys = sharedKeys;
  "shared/piclist-token.age".publicKeys = sharedKeys;
  "shared/qq-smtp-authcode.age".publicKeys = sharedKeys;
  "shared/twikoo-access-token.age".publicKeys = sharedKeys;
  "shared/xray-config.json.age".publicKeys = sharedKeys;

  # ----------------------------------------------------------------------------
  # Host-specific
  # ----------------------------------------------------------------------------
  "cloudcone-sc2/server-keys/us-1.age".publicKeys = allUserKeys ++ [ keys.hosts.us-1 ];
  # TODO: Create us-3.age after adding us-3 host key
  # "cloudcone-sc2/server-keys/us-3.age".publicKeys = allUserKeys ++ [ keys.hosts.us-3 ];
}
