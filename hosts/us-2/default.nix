{ hostName, ... }:

let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    ../_profiles/cloudcone-vps
    ../_profiles/server-baseline
  ];

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    inherit hostName;

    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "74.48.189.161";
          prefixLength = 26;
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

    defaultGateway = "74.48.189.129";
    defaultGateway6 = {
      address = "2607:f130:0:17d::1";
      interface = "eth0";
    };
  };

  # ============================================================================
  # Access (SSH)
  # ============================================================================
  hakula.access.ssh.authorizedKeys = [ keys.users.hakula-cloudcone ];

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
