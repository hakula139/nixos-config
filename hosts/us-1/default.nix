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
  hakula.dockerHub = {
    username = "hakula139";
    tokenAgeFile = ../../secrets/shared/dockerhub-token.age;
  };
  hakula.services.aria2.enable = true;
  hakula.services.backup = {
    enable = true;
    b2Bucket = "hakula-backup";
    backupPath = hostName;
    cloudreve.enable = true;
    twikoo.enable = true;
  };
  hakula.services.cachix.enable = true;
  hakula.services.clashGenerator.enable = true;
  hakula.services.cloudconeAgent = {
    enable = true;
    serverKeyAgeFile = ../../secrets/cloudcone-sc2/server-keys/${hostName}.age;
  };
  hakula.services.cloudreve.enable = true;
  hakula.services.piclist.enable = true;
  hakula.services.netdata.enable = true;
  hakula.services.nginx.enable = true;
  hakula.services.openssh = {
    enable = true;
    ports = [ 35060 ];
  };
  hakula.services.postgresql.enable = true;
  hakula.services.xray = {
    enable = true;
    ws.enable = true;
  };

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.05";
}
