# ==============================================================================
# hakula-devvm Host Configuration
# ==============================================================================

{
  lib,
  corpDomain,
  repoModules,
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
    repoModules.profiles.platform.container
  ];

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking.hostName = "hakula-devvm";

  # DNS config (nameservers, search domain) comes from bind-mounted host
  # /etc/resolv.conf — see docker-compose.yml volumes.

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
      # SSH config comes from bind-mounted host ~/.ssh/config.
      programs.ssh.enable = lib.mkForce false;

      services.ssh-agent.enable = lib.mkForce false;
      services.syncthing.enable = lib.mkForce false;

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

      hakula.secrets.required = {
        "hakula-devvm/proxy-url" = { };
        github-pat.name = lib.mkForce "github/pat-work";
      };
    };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
