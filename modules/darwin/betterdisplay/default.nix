# ==================================================================================================
# BetterDisplay (Display Management)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  userName = config.hakula.user.name;
  app = "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay";
  licenseFile = config.age.secrets.betterdisplay-license.path;

  activateLicense = repoLib.mkNuCommand {
    inherit pkgs;
    name = "betterdisplay-activate-license";
    script = ./activate-license.nu;

    flags = {
      inherit app;
      license-file = licenseFile;
    };
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
  homebrew.casks = [
    "betterdisplay"
  ];

  # ------------------------------------------------------------------------------------------------
  # Secrets
  # ------------------------------------------------------------------------------------------------
  age.secrets.betterdisplay-license = repoLib.secrets.mkDarwinUserSecret userName {
    name = "betterdisplay/license";
  };

  # ------------------------------------------------------------------------------------------------
  # Launchd agents (macOS)
  # ------------------------------------------------------------------------------------------------
  home-manager.users.${userName}.launchd.agents.betterdisplay-license = {
    enable = true;
    config = {
      ProgramArguments = [ (lib.getExe activateLicense) ];
      RunAtLoad = true;
      WatchPaths = [
        "/Applications/BetterDisplay.app"
        licenseFile
      ];

      ProcessType = "Background";
    };
  };
}
