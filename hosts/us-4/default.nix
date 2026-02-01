{ hostName, ... }:

let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    ../_profiles/dmit
  ];

  # ============================================================================
  # Networking
  # ============================================================================
  networking.hostName = hostName;

  # ============================================================================
  # Access (SSH)
  # ============================================================================
  hakula.access.ssh.authorizedKeys = [ keys.users.hakula-dmit ];

  # ============================================================================
  # Distributed Builds
  # ============================================================================
  hakula.builders.enable = true;

  # ============================================================================
  # Credentials
  # ============================================================================
  hakula.cachix.enable = true;
  hakula.claude-code.enable = true;
  hakula.dockerHub = {
    username = "hakula139";
    tokenAgeFile = ../../secrets/shared/dockerhub-token.age;
  };
  hakula.mcp.enable = true;

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.aria2.enable = true;
  hakula.services.backup = {
    enable = true;
    b2Bucket = "hakula-backup";
    backupPath = hostName;
    cloudreve.enable = true;
    twikoo.enable = true;
  };
  hakula.services.clashGenerator.enable = true;
  hakula.services.cloudreve = {
    enable = true;
    umami = {
      enable = true;
      workerHost = "b2.hakula.xyz";
    };
  };
  hakula.services.piclist.enable = true;
  hakula.services.netdata.enable = true;
  hakula.services.nginx.enable = true;
  hakula.services.openssh = {
    enable = true;
    ports = [ 35060 ];
  };
  hakula.services.postgresql.enable = true;
  hakula.services.umami.enable = true;
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
