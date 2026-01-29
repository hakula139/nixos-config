{ ... }:

{
  imports = [
    ../_profiles/docker
  ];

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    hostName = "hakula-devvm";
    nameservers = [
      "10.0.0.5"
      "10.0.0.6"
    ];
    search = [ "saljiut.jqdomain.com" ];
  };

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
