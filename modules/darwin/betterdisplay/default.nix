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
  emailFile = config.sops.secrets.betterdisplay-email.path;
  keyFile = config.sops.secrets.betterdisplay-key.path;

  activateLicense = repoLib.mkNuCommand {
    inherit pkgs;
    name = "betterdisplay-activate-license";
    script = ./activate-license.nu;

    flags = {
      inherit app;
      email-file = emailFile;
      key-file = keyFile;
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
  sops.secrets = {
    betterdisplay-email = repoLib.secrets.mkSecret {
      name = "betterdisplay/email";
      owner = userName;
    };

    betterdisplay-key = repoLib.secrets.mkSecret {
      name = "betterdisplay/key";
      owner = userName;
    };
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
        emailFile
        keyFile
      ];

      ProcessType = "Background";
    };
  };
}
