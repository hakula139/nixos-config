{
  config,
  pkgs,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# PicList (Image Upload Server)
# ==============================================================================

let
  cfg = config.hakula.services.piclist;

  piclistServer = import ./server {
    inherit pkgs;
    nodejs = cfg.nodejs;
    configPath = config.age.secrets.piclist-config.path;
    tokenPath = config.age.secrets.piclist-token.path;
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.piclist = {
    enable = lib.mkEnableOption "PicList image upload server";

    nodejs = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nodejs_24;
      description = "Node.js package / version to use";
    };

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
    users.users.piclist = {
      isSystemUser = true;
      group = "piclist";
    };
    users.groups.piclist = { };

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.piclist-config = secrets.mkSecret {
      name = "piclist-config.json";
      owner = "piclist";
      group = "piclist";
    };

    age.secrets.piclist-token = secrets.mkSecret {
      name = "piclist-token";
      owner = "piclist";
      group = "piclist";
    };

    # --------------------------------------------------------------------------
    # Systemd service
    # --------------------------------------------------------------------------
    systemd.services.piclist = {
      description = "PicList image upload server";
      documentation = [ "https://github.com/Kuingsmile/PicList-Core" ];

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe piclistServer;
        Restart = "on-failure";
        RestartSec = "5s";
        User = "piclist";
        Group = "piclist";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        UMask = "0077";
        StateDirectory = "%N";
        StateDirectoryMode = "0750";
        WorkingDirectory = "%S/%N";
        Environment = [
          "HOME=%S/%N"
        ];
      };

      restartTriggers = [
        config.age.secrets.piclist-config.file
        config.age.secrets.piclist-token.file
      ];
    };
  };
}
