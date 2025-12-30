# ==============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ==============================================================================

let
  keys = import ./keys.nix;
  allUserKeys = builtins.attrValues keys.users;
  allHostKeys = builtins.attrValues keys.hosts;
  allWorkstationKeys = builtins.attrValues keys.workstations;
  serverKeys = allUserKeys ++ allHostKeys;
in
{
  # ----------------------------------------------------------------------------
  # Server secrets
  # ----------------------------------------------------------------------------
  "shared/aria2-rpc-secret.age".publicKeys = serverKeys;
  "shared/backup-env.age".publicKeys = serverKeys;
  "shared/backup-restic-password.age".publicKeys = serverKeys;
  "shared/cachix-auth-token.age".publicKeys = serverKeys;
  "shared/clash-users.json.age".publicKeys = serverKeys;
  "shared/cloudflare-credentials.age".publicKeys = serverKeys;
  "shared/dockerhub-token.age".publicKeys = serverKeys;
  "shared/piclist-config.json.age".publicKeys = serverKeys;
  "shared/piclist-token.age".publicKeys = serverKeys;
  "shared/qq-smtp-authcode.age".publicKeys = serverKeys;
  "shared/twikoo-access-token.age".publicKeys = serverKeys;
  "shared/xray-config.json.age".publicKeys = serverKeys;
  "cloudcone-sc2/server-keys/us-1.age".publicKeys = allUserKeys ++ [ keys.hosts.us-1 ];
  # TODO: Create us-3.age after adding us-3 host key
  # "cloudcone-sc2/server-keys/us-3.age".publicKeys = allUserKeys ++ [ keys.hosts.us-3 ];

  # ----------------------------------------------------------------------------
  # Workstation secrets
  # ----------------------------------------------------------------------------
  "workstation/brave-api-key.age".publicKeys = allWorkstationKeys;
  "workstation/context7-api-key.age".publicKeys = allWorkstationKeys;
}
