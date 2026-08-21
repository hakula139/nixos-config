# ==============================================================================
# US-1 Host Configuration
# ==============================================================================

{
  lib,
  keys,
  repo,
  hostName,
  ...
}:

{
  imports = [
    repo.profiles.platform.cloudcone-sc2
    repo.profiles.role.server
  ];

  # ----------------------------------------------------------------------------
  # Generation Management
  # ----------------------------------------------------------------------------
  boot.loader.grub.configurationLimit = lib.mkForce 10;

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    inherit hostName;

    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = "148.135.55.79";
          prefixLength = 25;
        }
      ];
      ipv6.addresses = [
        {
          address = "2607:f130:0:10d::7f";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:10d::80";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:10d::81";
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = "148.135.55.1";
    defaultGateway6 = "2607:f130:0:10d::1";
  };

  # ----------------------------------------------------------------------------
  # Access (SSH)
  # ----------------------------------------------------------------------------
  hakula.access.ssh.authorizedKeys = [ keys.users.cloudcone ];

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  hakula.services.backup = {
    enable = true;
    b2Bucket = "hakula-backup";
    peertube = {
      enable = true;
      schedule = "*-*-* 03:00:00";
    };
  };
  hakula.services.cloudconeAgent = {
    enable = true;
    serverKeyAgeFile = lib.path.append repo.root "secrets/cloudcone/server-key-${hostName}.age";
  };
  hakula.services.peertube = {
    enable = true;
    b2Bucket = "hakula-videos";
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.05";
}
