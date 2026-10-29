# ==================================================================================================
# PicList (Image Upload Server)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.piclist;

  piclistServer = import ./server {
    inherit pkgs lib;
    inherit (cfg) nodejs port;
    configPath = config.age.secrets.piclist-config.path;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
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

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # User & Group
    # ----------------------------------------------------------------------------------------------
    users.users.piclist = {
      isSystemUser = true;
      group = "piclist";
    };

    users.groups.piclist = { };

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    age.secrets.piclist-config = repoLib.secrets.mkSecret {
      name = "piclist/config.json";
      owner = "piclist";
      group = "piclist";
    };

    # ----------------------------------------------------------------------------------------------
    # Systemd service
    # ----------------------------------------------------------------------------------------------
    systemd.services.piclist = lib.mkMerge [
      repoLib.systemd.restartUnit

      {
        description = "PicList image upload server";
        documentation = [ "https://github.com/Kuingsmile/PicList-Core" ];

        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = repoLib.systemd.hardening // {
          Type = "simple";
          ExecStart = lib.getExe piclistServer;
          User = "piclist";
          Group = "piclist";
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
        ];
      }
    ];
  };
}
