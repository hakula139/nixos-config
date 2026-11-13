# ==================================================================================================
# DevVM Host Configuration
# ==================================================================================================

{
  lib,
  corpHosts,
  repo,
  repoLib,
  ...
}:

let
  inherit (corpHosts) wildcardDomain;

  commonMcpServers = repoLib.llmAssistants.mcpOptions.corpServerNames;

  proxyUrlSecret = "devvm/proxy-url";
  proxyNoProxy = [
    wildcardDomain
  ];
in
{
  imports = [
    repo.profiles.platform.container
  ];

  # ------------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------------
  networking.hostName = "devvm";

  # DNS comes from bind-mounted /etc/resolv.conf.

  # ------------------------------------------------------------------------------------------------
  # Nix Daemon Proxy
  # ------------------------------------------------------------------------------------------------
  hakula.nix-daemon.proxy = {
    enable = true;
    secretUrlFile = repoLib.secrets.secretPath proxyUrlSecret;
    noProxy = proxyNoProxy;
  };

  # ------------------------------------------------------------------------------------------------
  # User Configuration
  # ------------------------------------------------------------------------------------------------
  hakula.user.name = "root";

  # ------------------------------------------------------------------------------------------------
  # Home Manager Overrides
  # ------------------------------------------------------------------------------------------------
  home-manager.users.root =
    { secretPath, ... }:
    {
      # --------------------------------------------------------------------------------------------
      # Nix
      # --------------------------------------------------------------------------------------------
      hakula.nix.configPath = "/root/workspace/gitlab/nixos-config";

      # --------------------------------------------------------------------------------------------
      # Mirrors
      # --------------------------------------------------------------------------------------------
      hakula.corp-mirrors.enable = true;

      # --------------------------------------------------------------------------------------------
      # Assistant Tooling
      # --------------------------------------------------------------------------------------------
      home.sessionVariables.IS_SANDBOX = "1";

      hakula.llm-assistants = {
        enable = lib.mkDefault true;
        proxy = {
          enable = true;
          secretUrlFile = secretPath proxyUrlSecret;
          noProxy = proxyNoProxy;
        };
      };

      hakula.claude-code = {
        auth.defaultProfile = "corp-gateway-anthropic";
        mcp.enabledServers = commonMcpServers;
      };

      hakula.codex.mcp.enabledServers = commonMcpServers;

      hakula.omp.mcp.enabledServers = commonMcpServers;

      # --------------------------------------------------------------------------------------------
      # Secrets
      # --------------------------------------------------------------------------------------------
      hakula.secrets.required.${proxyUrlSecret} = { };

      # --------------------------------------------------------------------------------------------
      # Services
      # --------------------------------------------------------------------------------------------
      # SSH config comes from bind-mounted host ~/.ssh/config.
      programs.ssh.enable = lib.mkForce false;

      services.ssh-agent.enable = lib.mkForce false;
    };

  # ------------------------------------------------------------------------------------------------
  # System State
  # ------------------------------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
