# ==================================================================================================
# Agenix Secrets Configuration
# This file defines which public keys can decrypt which secrets.
# ==================================================================================================

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
    us-4
    devvm
    ;
  inherit (keys.workstations) macbook wsl;

  # Common groupings
  allServersAndMacbook = allServers ++ [ macbook ];
  corpGatewayKeys = allWorkstations ++ [ devvm ];
  us1Only = allUsers ++ [ us-1 ];
  us4Only = allUsers ++ [ us-4 ];
in
{
  # ------------------------------------------------------------------------------------------------
  # Dev tool secrets
  # ------------------------------------------------------------------------------------------------
  "github/pat.age".publicKeys = allKeys;
  "gitlab/pat.age".publicKeys = allKeys;

  "llm-assistants/claude-oauth-token.age".publicKeys = allKeys;
  "llm-assistants/ikuncode-api-key.age".publicKeys = allKeys;
  "llm-assistants/yescode-api-key.age".publicKeys = allKeys;

  "llm-assistants/corp-gateway/cachain.crt.age".publicKeys = corpGatewayKeys;
  "llm-assistants/corp-gateway/claude-code-api-key.age".publicKeys = corpGatewayKeys;
  "llm-assistants/corp-gateway/codex-api-key.age".publicKeys = corpGatewayKeys;
  "llm-assistants/corp-gateway/omp-api-key.age".publicKeys = corpGatewayKeys;
  "llm-assistants/corp-gateway/opencode-api-key.age".publicKeys = corpGatewayKeys;
  "llm-assistants/corp-gateway/oxide-code-api-key.age".publicKeys = corpGatewayKeys;

  "llm-assistants/telegram-bot-token.age".publicKeys = allKeys;

  "llm-assistants/mcp/brave-api-key.age".publicKeys = allKeys;
  "llm-assistants/mcp/confluence-pat.age".publicKeys = allKeys;
  "llm-assistants/mcp/context7-api-key.age".publicKeys = allKeys;
  "llm-assistants/mcp/exa-api-key.age".publicKeys = allKeys;

  # ------------------------------------------------------------------------------------------------
  # Infrastructure secrets
  # ------------------------------------------------------------------------------------------------
  "builders/ssh-key.age".publicKeys = allServersAndMacbook;
  "cachix/auth-token.age".publicKeys = allKeys;
  "devvm/proxy-url.age".publicKeys = allWorkstations ++ [ devvm ];

  # ------------------------------------------------------------------------------------------------
  # All-server secrets
  # ------------------------------------------------------------------------------------------------
  "backup/env.age".publicKeys = allServers;
  "backup/restic-password.age".publicKeys = allServers;
  "cloudflare/credentials.age".publicKeys = allServers;
  "netdata/qq-smtp-authcode.age".publicKeys = allServers;
  "xray/reality-private-key.age".publicKeys = allServers;
  "xray/users.json.age".publicKeys = allServers;

  # ------------------------------------------------------------------------------------------------
  # Host-specific secrets (grouped by host scope)
  # ------------------------------------------------------------------------------------------------
  "cloudcone/server-key-us-1.age".publicKeys = us1Only;
  "peertube/env.age".publicKeys = us1Only;
  "peertube/secret.age".publicKeys = us1Only;

  "aria2/rpc-secret-cloudreve.age".publicKeys = us4Only;
  "piclist/config.json.age".publicKeys = us4Only;
  "piclist/token.age".publicKeys = us4Only;
  "umami/env.age".publicKeys = us4Only;

  # ------------------------------------------------------------------------------------------------
  # Workstation-only secrets
  # ------------------------------------------------------------------------------------------------
  "mihomo/secret.age".publicKeys = allWorkstations;
  "mihomo/subscription-url.age".publicKeys = allWorkstations;
  "wakatime/config.age".publicKeys = allWorkstations;

  "aria2/rpc-config-macbook.age".publicKeys = [ macbook ];
  "betterdisplay/license.age".publicKeys = [ macbook ];
  "drivedx/license.age".publicKeys = [ macbook ];
  "rclone/config.age".publicKeys = [ macbook ];

  "feishu/caldav.age".publicKeys = [ wsl ];
}
