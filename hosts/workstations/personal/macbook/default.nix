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
  hakula.services.corpTunnel.enable = true;
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
    hakula.codex.auth.enableCorpGateway = true;
    hakula.nix.configPath = "/Users/hakula/GitHub/nixos-config";
    services.listenbrainz-scrobbler.enable = true;
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = 6;
}
