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
    enableIPv6 = false; # IPv6 outbound is actually broken on CloudCone VPS
    useDHCP = false; # CloudCone requires static IP configuration

    interfaces.eth0 = {
      ipv4.addresses = [
        {
          address = "74.48.189.161";
          prefixLength = 26;
        }
      ];
    };

    defaultGateway = "74.48.189.129";

    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };

  # ============================================================================
  # Access (SSH)
  # ============================================================================
  hakula.access.ssh.authorizedKeys = [ keys.users.hakula-cloudcone ];

  # ============================================================================
  # Credentials
  # ============================================================================
  hakula.cachix.enable = true;
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
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
