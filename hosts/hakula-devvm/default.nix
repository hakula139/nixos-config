{ ... }:

{
  imports = [
    ../_profiles/docker
  ];

  # ============================================================================
  # Container Configuration
  # ============================================================================
  networking.hostName = "hakula-devvm";

  users.users.hakula = {
    uid = 1001;
    group = "hakula";
  };
  users.groups.hakula.gid = 1001;

  # ============================================================================
  # Home Manager Overrides
  # ============================================================================
  home-manager.users.hakula = {
    programs.ssh.matchBlocks = {
      "github.com" = {
        hostname = "github-proxy.jqdomain.com";
        forwardAgent = true;
      };
    };

    services.ssh-agent.enable = false;
    services.syncthing.enable = false;
  };

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
