# ==============================================================================
# BetterDisplay (Display Management)
# ==============================================================================

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
      licenseFile
      "--add-flag"
      app
    ];
  } (builtins.readFile ./activate-license.nu);
in
{
  homebrew.casks = [ "betterdisplay" ];

  age.secrets.betterdisplay-license = repoLib.secrets.mkSecret {
    name = "betterdisplay/license";
    owner = userName;
    group = "staff";
  };

  home-manager.users.${userName}.launchd.agents.betterdisplay-license = {
    enable = true;
    config = {
      ProgramArguments = [ "${activateLicense}" ];
      RunAtLoad = true;
      WatchPaths = [
        licenseFile
        "/Applications/BetterDisplay.app"
      ];
      ProcessType = "Background";
    };
  };
}
