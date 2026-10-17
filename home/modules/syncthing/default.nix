# ==================================================================================================
# Syncthing - Continuous File Synchronization
# Web UI: http://localhost:8384
# ==================================================================================================

{
  config,
  lib,
  hostName,
  ...
}:

let
  cfg = config.hakula.syncthing;

  homeDir = config.home.homeDirectory;
  syncDir = "${homeDir}/synced";

  syncDevices = {
    "hakula-macbook" = {
      id = "J6FXWYE-F6RNY3X-EEB7P3Q-A3XWLGC-3CG4LTQ-7LL3E76-Q4QVETI-BQD4CAR"; # cspell:disable-line
      addresses = [
        "tcp://hakula-macbook:22000"
        "dynamic"
      ];
    };
    "wsl" = {
      id = "LWCP7SR-HFEXQOS-5B4NACT-OGH5ESN-LPTZQDM-URC4FFG-PAT3XZG-BPI4KQW"; # cspell:disable-line
    };
  };

  mkActivityHistoryFolder = device: _: {
    name = "activity-history-${device}";
    value = {
      path = "${syncDir}/activity-history/${device}";
      type = if device == hostName then "sendonly" else "receiveonly";
      devices = builtins.attrNames syncDevices;
      ignorePerms = false;
      versioning = {
        type = "staggered";
        params = {
          cleanInterval = "3600"; # 1 hour
          maxAge = "604800"; # 7 days
        };
      };
    };
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.syncthing = {
    enable = lib.mkEnableOption "Syncthing sync of activity history between workstations";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      hakula.syncthing.enable = lib.mkDefault (syncDevices ? ${hostName});
    }

    (lib.mkIf cfg.enable {
      services.syncthing = {
        enable = true;

        settings = {
          devices = syncDevices;
          folders = lib.mapAttrs' mkActivityHistoryFolder syncDevices;
        };

        overrideDevices = true;
        overrideFolders = true;
      };
    })
  ];
}
