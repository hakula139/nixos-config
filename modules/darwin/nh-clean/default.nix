# ==================================================================================================
# Nh Clean (launchd)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  platformSettings,
  ...
}:

{
  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config.launchd.daemons.nh-clean = {
    command = "${lib.getExe pkgs.nh} clean all ${platformSettings.nhCleanArgs}";
    path = [
      config.nix.package
      "/usr/sbin"
    ];
    serviceConfig = {
      StartCalendarInterval = [
        {
          Hour = 6;
          Minute = 0;
        }
      ];

      StandardOutPath = "/var/log/nh-clean.log";
      StandardErrorPath = "/var/log/nh-clean.log";
    };
  };
}
