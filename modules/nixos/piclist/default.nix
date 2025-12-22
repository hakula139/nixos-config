{
  config,
  lib,
  ...
}:

# ==============================================================================
# PicList (Image Upload Server)
# ==============================================================================

let
  cfg = config.hakula.services.piclist;
  containerName = "piclist";
  containerImage = "docker.io/kuingsmile/piclist:v2.0.4";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.piclist = {
    enable = lib.mkEnableOption "PicList image upload server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 36677;
      description = "Port for PicList HTTP server";
    };
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.piclist-config = {
      file = ../../../secrets/shared/piclist-config.json.age;
      mode = "0400";
    };

    age.secrets.piclist-token = {
      file = ../../../secrets/shared/piclist-token.age;
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Docker container
    # --------------------------------------------------------------------------
    virtualisation.docker.enable = true;

    virtualisation.oci-containers = {
      backend = "docker";

      containers.${containerName} = {
        image = containerImage;
        login = config.hakula.dockerHub.ociLogin;
        autoStart = true;

        cmd = [
          "sh"
          "-c"
          "picgo-server -c /config/config.json -k $(cat /config/token)"
        ];

        ports = [
          "127.0.0.1:${toString cfg.port}:36677"
        ];

        volumes = [
          "${config.age.secrets.piclist-config.path}:/config/config.json:ro"
          "${config.age.secrets.piclist-token.path}:/config/token:ro"
        ];
      };
    };

    # --------------------------------------------------------------------------
    # Systemd service
    # --------------------------------------------------------------------------
    systemd.services."docker-${containerName}" = {
      restartTriggers = [
        config.age.secrets.piclist-config.file
        config.age.secrets.piclist-token.file
      ];
    };
  };
}
