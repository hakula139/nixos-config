{ hostName, ... }:

let
  keys = import ../../secrets/keys.nix;
in
{
  imports = [
    ../_profiles/dmit
    ../_profiles/server-baseline
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
  # Credentials
  # ============================================================================
  hakula.dockerHub = {
    username = "hakula139";
    tokenAgeFile = ../../secrets/dockerhub-token.age;
  };

  # ============================================================================
  # Services
  # ============================================================================
  hakula.services.aria2.enable = true;
  hakula.services.backup = {
    enable = true;
    b2Bucket = "hakula-backup";
    cloudreve.enable = true;
    twikoo.enable = true;
    umami.enable = true;
  };
  hakula.services.clashGenerator.enable = true;
  hakula.services.cloudreve = {
    enable = true;
    umami = {
      enable = true;
      workerHost = "b2.hakula.xyz";
    };
  };
  hakula.services.clove.enable = true;
  hakula.services.fuclaude.enable = true;
  hakula.services.piclist.enable = true;
  hakula.services.postgresql.enable = true;
  hakula.services.umami.enable = true;

  # ============================================================================
  # System State
  # ============================================================================
  system.stateVersion = "25.11";
}
