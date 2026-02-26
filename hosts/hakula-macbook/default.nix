{
  keys,
  hostName,
  displayName,
  ...
}:

{
  imports = [
    ../../modules/darwin
  ];

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    inherit hostName;
    computerName = displayName;
    localHostName = hostName;
  };

  # ============================================================================
  # Access (SSH)
  # ============================================================================
  hakula.access.ssh.authorizedKeys = with keys.workstations; [
    hakula-macbook
    hakula-work
  ];

  # ============================================================================
  # Credentials
  # ============================================================================
  hakula.cachix.enable = true;

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.openssh.enable = true;

  # ============================================================================
  # Home Manager Overrides
  # ============================================================================
  home-manager.users.hakula = {
    hakula.claude-code = {
      enable = true;
      proxy.enable = true;
    };
    hakula.codex = {
      enable = true;
      proxy.enable = true;
    };
    hakula.cursor.nixd.flakePath = "/Users/hakula/GitHub/nixos-config";
  };

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = 6;
}
