{
  lib,
  keys,
  hostName,
  ...
}:

{
  imports = [
    ../_profiles/cloudcone-sc2
    ../_profiles/server-baseline
  ];

  # ============================================================================
  # Generation Management
  # ============================================================================
  boot.loader.grub.configurationLimit = lib.mkForce 10;

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    inherit hostName;

    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = "74.48.108.20";
          prefixLength = 24;
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

    defaultGateway = "74.48.108.1";
    defaultGateway6 = "2607:f130:0:10d::1";
  };

  # ============================================================================
  # Access (SSH)
  # ============================================================================
  hakula.access.ssh.authorizedKeys = [ keys.users.hakula-cloudcone ];

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.cloudconeAgent = {
    enable = true;
    serverKeyAgeFile = ../../secrets/cloudcone-server-key-${hostName}.age;
  };
  hakula.services.peertube = {
    enable = true;
    b2Bucket = "hakula-videos";
  };

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.05";
}
