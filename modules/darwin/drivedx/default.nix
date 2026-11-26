# ==================================================================================================
# DriveDx (Drive Health Diagnostics)
# ==================================================================================================

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
  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
  homebrew.casks = [
    "drivedx"
  ];

  # ------------------------------------------------------------------------------------------------
  # Secrets
  # ------------------------------------------------------------------------------------------------
  sops.secrets.drivedx-license = repoLib.secrets.mkSecret {
    name = "drivedx/license";
    owner = userName;
    mode = "0600";
    path = licensePath;
  };

  # ------------------------------------------------------------------------------------------------
  # Directory management
  # ------------------------------------------------------------------------------------------------
  system.activationScripts.preActivation.text = lib.mkAfter ''
    install -dm0700 \
      -o ${lib.escapeShellArg userName} \
      -g staff \
      ${lib.escapeShellArg licenseDir}
  '';
}
