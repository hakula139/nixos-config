# ==============================================================================
# DevVM Host Configuration
# ==============================================================================

{
  lib,
  corpHosts,
  repo,
  secrets,
  ...
}:

let
  inherit (corpHosts) wildcardDomain;

  commonMcpServers = [
    "atlassian"
    "filesystem"
    "git"
    "gitlab"
  ];

  claudeMcpServers = [
    "codex"
  ]
  ++ commonMcpServers;

  proxyUrlSecret = "devvm/proxy-url";
  proxyNoProxy = [ wildcardDomain ];
in
{
  imports = [
    repo.profiles.platform.container
  ];

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking.hostName = "devvm";

  # DNS comes from bind-mounted /etc/resolv.conf.

  # ----------------------------------------------------------------------------
  # Nix Daemon Proxy
  # ----------------------------------------------------------------------------
  hakula.nix-daemon.proxy = {
    enable = true;
    secretUrlFile = secrets.secretPath proxyUrlSecret;
    noProxy = proxyNoProxy;
  };

  # ----------------------------------------------------------------------------
  # User Configuration
  # ----------------------------------------------------------------------------
  hakula.user.name = "root";

  # ----------------------------------------------------------------------------
  # Home Manager Overrides
  # ----------------------------------------------------------------------------
  home-manager.users.root =
    { secretPath, ... }:
    {
      # ------------------------------------------------------------------------
      # Assistant Tooling
      # ------------------------------------------------------------------------
      hakula.claude-code = {
        auth.defaultProfile = "corp-gateway";
        mcp.enabledServers = claudeMcpServers;
        plugins.bundle = true;
      };

      hakula.codex.mcp.enabledServers = commonMcpServers;

      hakula.llm-assistants = {
        enable = lib.mkDefault true;
        proxy = {
          enable = true;
          secretUrlFile = secretPath proxyUrlSecret;
          noProxy = proxyNoProxy;
        };
      };

      hakula.opencode = {
        mcp.enabledServers = commonMcpServers;
        plugins.bundle = true;
      };

      # ------------------------------------------------------------------------
      # Secrets
      # ------------------------------------------------------------------------
      hakula.secrets.required = {
        ${proxyUrlSecret} = { };
        github-pat.name = lib.mkForce "github/pat-work";
      };

      # ------------------------------------------------------------------------
      # Services
      # ------------------------------------------------------------------------
      # SSH config comes from bind-mounted host ~/.ssh/config.
      programs.ssh.enable = lib.mkForce false;

      services.ssh-agent.enable = lib.mkForce false;
      services.syncthing.enable = lib.mkForce false;
    };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
