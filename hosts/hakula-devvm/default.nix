{ lib, ... }:

{
  imports = [
    ../_profiles/docker
  ];

  # ============================================================================
  # Networking
  # ============================================================================
  networking.hostName = "hakula-devvm";

  # DNS config (nameservers, search domain) comes from bind-mounted host
  # /etc/resolv.conf — see docker-compose.yml volumes.

  # ============================================================================
  # User Configuration
  # ============================================================================
  hakula.user.name = "root";

  # ============================================================================
  # Credentials
  # ============================================================================
  hakula.mcp.enable = true;

  # ============================================================================
  # Home Manager Overrides
  # ============================================================================
  home-manager.users.root = {
    # SSH config comes from bind-mounted host ~/.ssh/config.
    programs.ssh.enable = lib.mkForce false;

    services.ssh-agent.enable = false;
    services.syncthing.enable = false;
  };

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
