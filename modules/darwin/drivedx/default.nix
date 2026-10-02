# ==============================================================================
# DriveDx (Drive Health Diagnostics)
# ==============================================================================

{
  config,
  lib,
  repoLib,
  ...
}:

let
  userName = config.hakula.user.name;
  homeDir = config.users.users.${userName}.home;
  licenseDir = "${homeDir}/Library/Application Support/DriveDx";
  licensePath = "${licenseDir}/DriveDx.driveDxLicense";
in
{
  homebrew.casks = [ "drivedx" ];

  age.secrets.drivedx-license =
    repoLib.secrets.mkDarwinUserSecret userName {
      name = "drivedx/license";
      mode = "0600";
      path = licensePath;
    }
    // {
      symlink = false;
    };

  system.activationScripts.preActivation.text = lib.mkAfter ''
    install -d -m 0700 -o ${lib.escapeShellArg userName} -g staff ${lib.escapeShellArg licenseDir}
  '';
}
