{
  config,
  lib,
  ...
}:

# ==============================================================================
# PicList (Image Upload Server)
# ==============================================================================
# PicList runs as an HTTP server that accepts image uploads and forwards them to
# configured backends.
# Architecture: Client -> PicList -> WebDAV -> Cloudreve -> Tencent COS

let
  cfg = config.hakula.services.piclist;
  serviceName = "piclist";
  stateDir = "/var/lib/${serviceName}";
  containerName = serviceName;
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
    # User & Group
    # --------------------------------------------------------------------------
    users.users.${serviceName} = {
      isSystemUser = true;
      group = serviceName;
      extraGroups = [ "dockerhub" ];
      home = stateDir;
      createHome = true;
      linger = true;
      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
    };
    users.groups.${serviceName} = { };

    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.piclist-config = {
      file = ../../../secrets/shared/piclist-config.json.age;
      owner = serviceName;
      group = serviceName;
      mode = "0400";
    };

    age.secrets.piclist-token = {
      file = ../../../secrets/shared/piclist-token.age;
      owner = serviceName;
      group = serviceName;
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Filesystem layout
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 ${serviceName} ${serviceName} -"
    ];

    # --------------------------------------------------------------------------
    # Podman container
    # --------------------------------------------------------------------------
    virtualisation.podman.enable = true;

    virtualisation.oci-containers = {
      backend = "podman";

      containers.${containerName} = {
        image = containerImage;
        login = config.hakula.dockerHub.ociLogin;
        pull = "newer";
        autoStart = true;
        podman.user = serviceName;

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
    systemd.services."podman-${containerName}".restartTriggers = [
      config.age.secrets.piclist-config.file
      config.age.secrets.piclist-token.file
    ];
  };
}
