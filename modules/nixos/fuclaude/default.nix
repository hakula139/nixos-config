{
  config,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Fuclaude (Claude mirror)
# ==============================================================================

let
  cfg = config.hakula.services.fuclaude;
  serviceName = "fuclaude";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.fuclaude = {
    enable = lib.mkEnableOption "Fuclaude (Claude mirror)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8181;
      description = "Port for Fuclaude web interface";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "pengzhile/fuclaude:latest";
      description = "Docker image for Fuclaude";
    };

    realLogout = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether logout invalidates sessionKey immediately";
    };

    signupEnabled = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to allow new user signups";
    };

    showSessionKey = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to show sessionKey in the UI";
    };
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.fuclaude-env = secrets.mkSecret {
      name = "fuclaude-env";
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
        "127.0.0.1:${toString cfg.port}:8181"
      ];

      environment = {
        TZ = config.time.timeZone;
        FUCLAUDE_BIND = "0.0.0.0:8181";
        FUCLAUDE_TIMEOUT = "60";
        FUCLAUDE_REAL_LOGOUT = lib.boolToString cfg.realLogout;
        FUCLAUDE_SIGNUP_ENABLED = lib.boolToString cfg.signupEnabled;
        FUCLAUDE_SHOW_SESSION_KEY = lib.boolToString cfg.showSessionKey;
      };

      environmentFiles = [
        config.age.secrets.fuclaude-env.path
      ];
    };
  };
}
