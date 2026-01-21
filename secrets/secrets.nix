# ==============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ==============================================================================

let
  keys = import ./keys.nix;
  allUserKeys = builtins.attrValues keys.users;
  allHostKeys = builtins.attrValues keys.hosts;
  allServerKeys = allUserKeys ++ allHostKeys;
  allWorkstationKeys = builtins.attrValues keys.workstations;
  allKeys = allServerKeys ++ allWorkstationKeys;
in
{
  # ----------------------------------------------------------------------------
  # Server & Workstation shared secrets
  # ----------------------------------------------------------------------------
  "shared/brave-api-key.age".publicKeys = allKeys;
  "shared/context7-api-key.age".publicKeys = allKeys;
  "shared/github-pat.age".publicKeys = allKeys;

  # ----------------------------------------------------------------------------
  # Server shared secrets
  # ----------------------------------------------------------------------------
  "shared/aria2-rpc-secret.age".publicKeys = allServerKeys;
  "shared/backup-env.age".publicKeys = allServerKeys;
  "shared/backup-restic-password.age".publicKeys = allServerKeys;
  "shared/builder-ssh-key.age".publicKeys = allServerKeys;
  "shared/cachix-auth-token.age".publicKeys = allServerKeys;
  "shared/clash-users.json.age".publicKeys = allServerKeys;
  "shared/cloudflare-credentials.age".publicKeys = allServerKeys;
  "shared/dockerhub-token.age".publicKeys = allServerKeys;
  "shared/fuclaude-env.age".publicKeys = allServerKeys;
  "shared/piclist-config.json.age".publicKeys = allServerKeys;
  "shared/piclist-token.age".publicKeys = allServerKeys;
  "shared/qq-smtp-authcode.age".publicKeys = allServerKeys;
  "shared/twikoo-access-token.age".publicKeys = allServerKeys;
  "shared/umami-env.age".publicKeys = allServerKeys;
  "shared/xray-config.json.age".publicKeys = allServerKeys;

  # ----------------------------------------------------------------------------
  # Server-specific secrets
  # ----------------------------------------------------------------------------
  "cloudcone-sc2/server-keys/us-1.age".publicKeys = allUserKeys ++ [ keys.hosts.us-1 ];
  "cloudcone-sc2/server-keys/us-3.age".publicKeys = allUserKeys ++ [ keys.hosts.us-3 ];

  # ----------------------------------------------------------------------------
  # Workstation shared secrets
  # ----------------------------------------------------------------------------
  "shared/wakatime-config.age".publicKeys = allWorkstationKeys;
}
