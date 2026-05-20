# ==============================================================================
# devvm Host Configuration
# ==============================================================================

{
  lib,
  corpDomain,
  repo,
  ...
}:

let
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
        auth = {
          defaultProfile = "corp-gateway";
          enableCorpGateway = true;
        };
        mcp.enabledServers = claudeMcpServers;
        plugins.bundle = true;
      };

      hakula.codex.mcp.enabledServers = commonMcpServers;

      hakula.llm-assistants = {
        enable = lib.mkDefault true;
        proxy = {
          enable = true;
          secretUrlFile = secretPath "hakula-devvm/proxy-url";
          noProxy = [
            "localhost"
            "127.0.0.1"
            "10.*"
            ".${corpDomain}"
          ];
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
        "hakula-devvm/proxy-url" = { };
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
