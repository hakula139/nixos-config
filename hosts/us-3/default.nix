{ hostName, ... }:

{
  imports = [
    ../_profiles/cloudcone-sc2
  ];

  # ============================================================================
  # Networking
  # ============================================================================
  networking = {
    inherit hostName;
    useDHCP = false; # CloudCone requires static IP configuration

    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = "148.135.122.201";
          prefixLength = 26;
        }
      ];
      ipv6.addresses = [
        {
          address = "2607:f130:0:f0::78";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:f0::77";
          prefixLength = 64;
        }
        {
          address = "2607:f130:0:f0::76";
          prefixLength = 64;
        }
      ];
    };

    defaultGateway = "148.135.122.1";
    defaultGateway6 = "2607:f130:0:f0::1";

    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
      "2001:4860:4860::8888"
      "2606:4700:4700::1111"
    ];
  };

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.cachix.enable = true;
  # TODO: Enable cloudconeAgent after initial deployment and secret creation:
  # hakula.services.cloudconeAgent = {
  #   enable = true;
  #   serverKeyAgeFile = ../../secrets/cloudcone-sc2/server-keys/${hostName}.age;
  # };
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
