{ lib, ... }:

{
  # ============================================================================
  # Home Manager Settings
  # ============================================================================
  home = {
    username = "hakula_chen";
    homeDirectory = "/home/hakula_chen";
    stateVersion = "25.11";
  };

  # ============================================================================
  # Home Manager Modules
  # ============================================================================
  hakula.cursor.extensions.prune = false;

  # ============================================================================
  # SSH Configuration
  # ============================================================================
  programs.ssh.matchBlocks = {
    "github.com" = {
      hostname = "github-proxy.jqdomain.com";
      forwardAgent = true;
    };
  };

  # ============================================================================
  # Services
  # ============================================================================
  services.ssh-agent.enable = lib.mkForce false;
  services.syncthing.enable = lib.mkForce false;
}
