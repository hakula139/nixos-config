{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# PicList (Image Upload Server)
# ==============================================================================

let
  cfg = config.hakula.services.piclist;
  version = "2.0.4";
  picgoServerBin = "node_modules/.bin/picgo-server";
  piclistPkgJson = "node_modules/piclist/package.json";
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
    # Systemd service
    # --------------------------------------------------------------------------
    systemd.services.piclist = {
      description = "PicList image upload server";
      documentation = [ "https://github.com/Kuingsmile/PicList-Core" ];

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = [ cfg.nodejs ];

      preStart = ''
        cd "$STATE_DIRECTORY"

        installedVersion="$(${lib.getExe cfg.nodejs} -p "require('./${piclistPkgJson}').version" 2>/dev/null || true)"

        if [ ! -x "${picgoServerBin}" ] || [ "$installedVersion" != "${version}" ]; then
          rm -rf node_modules package.json package-lock.json
          npm init -y
          npm install piclist@${version}
        fi

        install -m 0600 ${config.age.secrets.piclist-config.path} config.json
      '';

      script = ''
        cd "$STATE_DIRECTORY"
        SECRET_KEY=$(cat ${config.age.secrets.piclist-token.path})
        exec "${picgoServerBin}" -c config.json -k "$SECRET_KEY"
      '';

      serviceConfig = {
        Type = "simple";
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
