# ==============================================================================
# US-2 Host Configuration
# ==============================================================================

{
  keys,
  repo,
  hostName,
  ...
}:

{
  imports = [
    repo.profiles.platform.cloudcone-vps
    repo.profiles.role.server
  ];

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    inherit hostName;

    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "117.55.232.113";
          prefixLength = 25;
        }
      ];
      ipv6.addresses = [
        {
          address = "2607:f130:0:17d::956:243a";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:17d::4313:915c";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:17d::de5b:134c";
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = "117.55.232.1";
    defaultGateway6 = {
      address = "2607:f130:0:17d::1";
      interface = "eth0";
    };
  };

  # ----------------------------------------------------------------------------
  # Access (SSH)
  # ----------------------------------------------------------------------------
  hakula.access.ssh.authorizedKeys = [ keys.users.cloudcone ];

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.11";
}
