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
  containerImage = "docker.io/kuingsmile/piclist:v2.0.4";
  stateDir = "/var/lib/piclist";
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
    # Users & Groups
    # --------------------------------------------------------------------------
    users.users.piclist = {
      isSystemUser = true;
      group = "piclist";
      home = stateDir;
      createHome = false;
    };

    users.groups.piclist = { };

    # --------------------------------------------------------------------------
    # Filesystem layout
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 piclist piclist - -"
    ];

    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.piclist-config = {
      file = ../../../secrets/shared/piclist-config.json.age;
      owner = "piclist";
      group = "piclist";
      mode = "0400";
    };

    age.secrets.piclist-token = {
      file = ../../../secrets/shared/piclist-token.age;
      owner = "piclist";
      group = "piclist";
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Docker container
    # --------------------------------------------------------------------------
    virtualisation.docker.enable = true;

    virtualisation.oci-containers = {
      backend = "docker";

      containers.piclist =
        let
          uid = config.users.users.piclist.uid;
          gid = config.users.groups.piclist.gid;
        in
        {
          image = containerImage;
          login = config.hakula.dockerHub.ociLogin;
          autoStart = true;
          user = "${toString uid}:${toString gid}";

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
            "${stateDir}:${stateDir}"
          ];

          environment = {
            HOME = stateDir;
            XDG_CONFIG_HOME = "${stateDir}/.config";
          };
        };
    };

    # --------------------------------------------------------------------------
    # Systemd service
    # --------------------------------------------------------------------------
    systemd.services."docker-piclist" = {
      restartTriggers = [
        config.age.secrets.piclist-config.file
        config.age.secrets.piclist-token.file
      ];
    };
  };
}
