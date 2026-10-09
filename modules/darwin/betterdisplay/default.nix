# ==================================================================================================
# BetterDisplay (Display Management)
# ==================================================================================================

{
  config,
  pkgs,
  repoLib,
  ...
}:

let
  userName = config.hakula.user.name;
  app = "/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay";
  licenseFile = config.age.secrets.betterdisplay-license.path;

  activateLicense = pkgs.writers.writeNu "betterdisplay-activate-license" {
    makeWrapperArgs = [
      "--add-flag"
      app

      "--add-flag"
      licenseFile
    ];
  } (builtins.readFile ./activate-license.nu);
in
{
  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
  homebrew.casks = [ "betterdisplay" ];

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
      ProgramArguments = [ "${activateLicense}" ];
      RunAtLoad = true;
      WatchPaths = [
        "/Applications/BetterDisplay.app"
        licenseFile
      ];
      ProcessType = "Background";
    };
  };
}
