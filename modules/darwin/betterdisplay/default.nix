# ==============================================================================
# BetterDisplay (Display Management)
# ==============================================================================

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
  activateLicense = pkgs.writeText "betterdisplay-activate-license.nu" (
    builtins.readFile ./activate-license.nu
  );
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
      ProgramArguments = [
        (lib.getExe pkgs.nushell)
        "--no-config-file"
        "${activateLicense}"
        config.age.secrets.betterdisplay-license.path
        app
      ];
      RunAtLoad = true;
      WatchPaths = [
        config.age.secrets.betterdisplay-license.path
        "/Applications/BetterDisplay.app"
      ];
      ProcessType = "Background";
    };
  };
}
