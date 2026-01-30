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
  # Credentials
  # ============================================================================
  hakula.mcp.enable = true;

  # ============================================================================
  # Environment
  # ============================================================================
  # Rootless Docker maps container root to the host user, so running as root
  # inside the container is safe and avoids bind-mount permission issues.
  # Use hakula's per-user profile so root gets the full HM environment.
  environment.profiles = [ "/etc/profiles/per-user/hakula" ];

  # ============================================================================
  # Home Manager Overrides
  # ============================================================================
  home-manager.users.hakula = {
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
