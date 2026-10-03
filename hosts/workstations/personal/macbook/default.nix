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
  hakula.services.aria2 = {
    enable = true;
    webUi.enable = true;
  };
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
    hakula.rclone = {
      enable = true;
      mounts = {
        Hakula-Cloud.remote = "hakula_cloud:";
        BMS.remote = "bms:";
        Images.remote = "images:";
        B2 = {
          remote = "b2:hakula";
          cacheMode = "full";
        };
      };
    };
    services.listenbrainz-scrobbler.enable = true;
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = 6;
}
