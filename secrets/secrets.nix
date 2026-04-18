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
  inherit (keys.hosts)
    us-1
    us-3
    us-4
    hakula-devvm
    ;
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
  "confluence-pat.age".publicKeys = allKeys;
  "context7-api-key.age".publicKeys = allKeys;
  "corp-cachain.crt.age".publicKeys = allWorkstations ++ [ hakula-devvm ];
  "devvm-proxy-url.age".publicKeys = allWorkstations ++ [ hakula-devvm ];
  "github/pat-personal.age".publicKeys = allKeys;
  "github/pat-work.age".publicKeys = allKeys;
  "llm-assistants/ikuncode-api-key.age".publicKeys = allKeys;
  "llm-assistants/litellm-api-key.age".publicKeys = allWorkstations ++ [ hakula-devvm ];
  "llm-assistants/oauth-token.age".publicKeys = allKeys;
  "llm-assistants/yescode-api-key.age".publicKeys = allKeys;

  # ----------------------------------------------------------------------------
  # Infrastructure secrets
  # ----------------------------------------------------------------------------
  "builder-ssh-key.age".publicKeys = allServersAndMacbook;
  "cachix-auth-token.age".publicKeys = allServersAndMacbook;

  # ----------------------------------------------------------------------------
  # All-server secrets
  # ----------------------------------------------------------------------------
  "backup/env.age".publicKeys = allServers;
  "backup/restic-password.age".publicKeys = allServers;
  "cloudflare-credentials.age".publicKeys = allServers;
  "qq-smtp-authcode.age".publicKeys = allServers;
  "xray-config.json.age".publicKeys = allServers;

  # ----------------------------------------------------------------------------
  # Host-specific secrets
  # ----------------------------------------------------------------------------
  "aria2-rpc-secret.age".publicKeys = us4Only;
  "clash-users.json.age".publicKeys = us4Only;
  "cloudcone/server-key-us-1.age".publicKeys = us1Only;
  "cloudcone/server-key-us-3.age".publicKeys = us3Only;
  "clove-env.age".publicKeys = us4Only;
  "dockerhub-token.age".publicKeys = us4Only;
  "fuclaude-env.age".publicKeys = us4Only;
  "peertube-env.age".publicKeys = us1Only;
  "peertube-secret.age".publicKeys = us1Only;
  "piclist-config.json.age".publicKeys = us4Only;
  "piclist-token.age".publicKeys = us4Only;
  "twikoo-access-token.age".publicKeys = us4Only;
  "umami-env.age".publicKeys = us4Only;

  # ----------------------------------------------------------------------------
  # Workstation-only secrets
  # ----------------------------------------------------------------------------
  "mihomo/secret.age".publicKeys = allWorkstations;
  "mihomo/subscription-url.age".publicKeys = allWorkstations;
  "wakatime-config.age".publicKeys = allWorkstations;
}
