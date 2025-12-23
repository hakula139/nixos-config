# ==============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ==============================================================================

let
  keys = import ./keys.nix;
  allUserKeys = builtins.attrValues keys.users;
  allHostKeys = builtins.attrValues keys.hosts;

  sharedKeys = allUserKeys ++ allHostKeys;
  cloudconeSc2Keys = allUserKeys ++ [ keys.hosts.cloudcone-sc2 ];
in
{
  # ----------------------------------------------------------------------------
  # Shared (multi-host)
  # ----------------------------------------------------------------------------
  "shared/aria2-rpc-secret.age".publicKeys = sharedKeys;
  "shared/backup-env.age".publicKeys = sharedKeys;
  "shared/backup-restic-password.age".publicKeys = sharedKeys;
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
  "cloudcone-sc2/server-key.age".publicKeys = cloudconeSc2Keys;
}
