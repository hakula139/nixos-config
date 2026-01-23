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
    useDHCP = false;

    # Disable IPv6 privacy extensions (RFC 4941) to prevent the kernel from
    # generating temporary addresses that would be preferred as the source
    # address for outbound connections. CloudCone VPS only routes traffic from
    # the statically assigned IPv6 addresses below.
    tempAddresses = "disabled";

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

    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
      "2001:4860:4860::8888"
      "2606:4700:4700::1111"
    ];
  };

  # ============================================================================
  # IPv6 Configuration: Disable SLAAC and Router Advertisements
  # ============================================================================
  # CloudCone assigns static IPv6 addresses, but the kernel was creating
  # additional SLAAC / autoconf addresses via router advertisements and using
  # them as the default source for outbound traffic. This broke IPv6
  # connectivity because the provider only routes the static addresses.
  #
  # Solution: Disable autoconf and RA processing on eth0. These sysctls are
  # applied early in the boot process (before networking starts), preventing
  # dynamic addresses from being created in the first place.

  boot.kernel.sysctl = {
    "net.ipv6.conf.eth0.autoconf" = 0;
    "net.ipv6.conf.eth0.accept_ra" = 0;
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
