{
  lib,
  secrets,
  ...
}:

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
  # Assistant Tooling
  # ============================================================================
  hakula.llm-assistants.enable = lib.mkDefault true;

  # ============================================================================
  # Home Manager Overrides
  # ============================================================================
  home-manager.users.root = {
    # SSH config comes from bind-mounted host ~/.ssh/config.
    programs.ssh.enable = lib.mkForce false;

    services.ssh-agent.enable = lib.mkForce false;
    services.syncthing.enable = lib.mkForce false;
  };

  # ============================================================================
  # Secret Overrides
  # ============================================================================
  age.secrets.github-pat.file = lib.mkForce (secrets.secretFile "github-pat-work");

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
