{
  config,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Clove (Claude API reverse proxy)
# ==============================================================================

let
  cfg = config.hakula.services.clove;
  serviceName = "clove";
  stateDir = "/var/lib/${serviceName}";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.clove = {
    enable = lib.mkEnableOption "Clove (Claude API reverse proxy)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 5201;
      description = "Port for Clove API server";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "mirrorange/clove:latest";
      description = "Docker image for Clove";
    };
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.clove-env = secrets.mkSecret {
      name = "clove-env";
      owner = "root";
      group = "root";
    };

    # --------------------------------------------------------------------------
    # Container (podman)
    # --------------------------------------------------------------------------
    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers.${serviceName} = {
      image = cfg.image;
      login = config.hakula.dockerHub.ociLogin;

      ports = [
        "127.0.0.1:${toString cfg.port}:5201"
      ];

      volumes = [
        "${stateDir}:/data"
      ];

      environment = {
        # Server settings
        HOST = "0.0.0.0";
        PORT = "5201";
        DATA_FOLDER = "/data";
        TZ = config.time.timeZone;

        # Content processing
        USE_REAL_ROLES = "true";
        CUSTOM_HUMAN_NAME = "Hakula";
        CUSTOM_ASSISTANT_NAME = "Claude";
        ALLOW_EXTERNAL_IMAGES = "true";

        # Feature flags
        PRESERVE_CHATS = "true";
      };

      environmentFiles = [
        config.age.secrets.clove-env.path
      ];
    };

    # --------------------------------------------------------------------------
    # Filesystem layout
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0755 root root - -"
    ];
  };
}
