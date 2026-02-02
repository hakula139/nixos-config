{ hostName, ... }:

let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    ../_profiles/cloudcone-vps
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
  # Distributed Builds
  # ============================================================================
  hakula.builders.enable = true;

  # ============================================================================
  # Credentials
  # ============================================================================
  hakula.cachix.enable = true;
  hakula.claude-code.enable = true;
  hakula.mcp.enable = true;

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.netdata.enable = true;
  hakula.services.nginx.enable = true;
  hakula.services.openssh = {
    enable = true;
    ports = [ 35060 ];
  };
  hakula.services.xray = {
    enable = true;
    ws.enable = true;
  };

  # ============================================================================
  # Home Manager Modules
  # ============================================================================
  home-manager.users.hakula.hakula.claude-code.enable = true;

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
