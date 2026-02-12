# ==============================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ==============================================================================

let
  keys = import ./keys.nix;

  allUsers = builtins.attrValues keys.users;
  allHosts = builtins.attrValues keys.hosts;
  allServers = allUsers ++ allHosts;
  allWorkstations = builtins.attrValues keys.workstations;
  allKeys = allServers ++ allWorkstations;

  # Per-host shortcuts
  inherit (keys.hosts) us-1 us-3 us-4;
  inherit (keys.workstations) hakula-macbook;

  # Common groupings
  allServersAndMacbook = allServers ++ [ hakula-macbook ];
  us1Only = allUsers ++ [ us-1 ];
  us3Only = allUsers ++ [ us-3 ];
  us4Only = allUsers ++ [ us-4 ];
in
{
  # ----------------------------------------------------------------------------
  # Dev tool secrets
  # ----------------------------------------------------------------------------
  "brave-api-key.age".publicKeys = allKeys;
  "claude-code-oauth-token.age".publicKeys = allKeys;
  "context7-api-key.age".publicKeys = allKeys;
  "github-pat.age".publicKeys = allKeys;

  # ----------------------------------------------------------------------------
  # Infrastructure secrets
  # ----------------------------------------------------------------------------
  "builder-ssh-key.age".publicKeys = allServersAndMacbook;
  "cachix-auth-token.age".publicKeys = allServersAndMacbook;

  # ----------------------------------------------------------------------------
  # All-server secrets
  # ----------------------------------------------------------------------------
  "cloudflare-credentials.age".publicKeys = allServers;
  "qq-smtp-authcode.age".publicKeys = allServers;
  "xray-config.json.age".publicKeys = allServers;

  # ----------------------------------------------------------------------------
  # Host-specific secrets
  # ----------------------------------------------------------------------------
  "aria2-rpc-secret.age".publicKeys = us4Only;
  "backup-env.age".publicKeys = us4Only;
  "backup-restic-password.age".publicKeys = us4Only;
  "clash-users.json.age".publicKeys = us4Only;
  "cloudcone-server-key-us-1.age".publicKeys = us1Only;
  "cloudcone-server-key-us-3.age".publicKeys = us3Only;
  "clove-env.age".publicKeys = us4Only;
  "dockerhub-token.age".publicKeys = us4Only;
  "fuclaude-env.age".publicKeys = us4Only;
  "piclist-config.json.age".publicKeys = us4Only;
  "piclist-token.age".publicKeys = us4Only;
  "twikoo-access-token.age".publicKeys = us4Only;
  "umami-env.age".publicKeys = us4Only;

  # ----------------------------------------------------------------------------
  # Workstation-only secrets
  # ----------------------------------------------------------------------------
  "mihomo-secret.age".publicKeys = allWorkstations;
  "mihomo-subscription-url.age".publicKeys = allWorkstations;
  "wakatime-config.age".publicKeys = allWorkstations;
}
