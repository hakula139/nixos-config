# ==============================================================================
# us-3 Host Configuration
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
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    inherit hostName;

    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = "148.135.122.201";
          prefixLength = 26;
        }
      ];
    };

    interfaces.ens4 = {
      ipv6.addresses = [
        {
          address = "2607:f130:0:f0::76";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:f0::77";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:f0::78";
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = "148.135.122.193";
    defaultGateway6 = {
      address = "2607:f130:0:f0::1";
      interface = "ens4";
    };
  };

  # ----------------------------------------------------------------------------
  # Access (SSH)
  # ----------------------------------------------------------------------------
  hakula.access.ssh.authorizedKeys = [ keys.users.hakula-cloudcone ];

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  hakula.services.cloudconeAgent = {
    enable = true;
    serverKeyAgeFile = lib.path.append repo.root "secrets/cloudcone/server-key-${hostName}.age";
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
