# ==================================================================================================
# /tmp Cleanup
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  userName = config.hakula.user.name;
  homeDir = config.users.users.${userName}.home;
  logFile = "${homeDir}/Library/Logs/tmp-cleanup.log";

  cleanup = pkgs.writers.writeNu "tmp-cleanup" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.lsof
      ])
    ];
  } (builtins.readFile ./tmp-cleanup.nu);
in
{
  # ------------------------------------------------------------------------------------------------
  # Launchd agents (macOS)
  # ------------------------------------------------------------------------------------------------
  home-manager.users.${userName}.launchd.agents.tmp-cleanup = {
    enable = true;
    config = {
      ProgramArguments = [ "${cleanup}" ];
      StartInterval = 3600;
      ProcessType = "Background";
      StandardOutPath = logFile;
      StandardErrorPath = logFile;
    };
  };
}
