# ==============================================================================
# MacBook Darwin Configuration
# ==============================================================================

{
  pkgs,
  repo,
  hostName,
  displayName,
  ...
}:

{
  imports = [
    repo.modules.darwin
    repo.profiles.role.workstation
  ];

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    inherit hostName;
    computerName = displayName;
    localHostName = hostName;
  };

  # ----------------------------------------------------------------------------
  # Packages
  # ----------------------------------------------------------------------------
  environment.systemPackages = [ pkgs.peertube-runner ];

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  hakula.services.corpGateway.enable = true;
  hakula.services.openssh.enable = true;
  hakula.services.tailscale = {
    enable = true;
    userspaceNetworking = true;
  };

  # ----------------------------------------------------------------------------
  # Home Manager Overrides
  # ----------------------------------------------------------------------------
  home-manager.users.hakula = {
    hakula.claude-code.auth = {
      defaultProfile = "official";
      enableCorpGateway = true;
    };

    hakula.cursor.nixd.flakePath = "/Users/hakula/GitHub/nixos-config";
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = 6;
}
