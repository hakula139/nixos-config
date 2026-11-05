# ==================================================================================================
# Auth Profile Switcher
# ==================================================================================================

{
  pkgs,
  lib,
  mkNuCommand,
}:

{
  name,
  assistant,
  stateDir,
  extension,
  profiles,
  defaultProfile,
  configFile ? null,
  resetKeys ? [ ],
}:

let
  profilesDir = "${stateDir}/profiles";
in
{
  package = mkNuCommand {
    inherit pkgs name;
    script = ./profile-switch.nu;
    runtimeInputs = [ pkgs.coreutils ];

    config = {
      inherit
        assistant
        stateDir
        profilesDir
        extension
        defaultProfile
        configFile
        resetKeys
        ;
    };
  };

  files = lib.mapAttrs' (
    profile: source: lib.nameValuePair "${profilesDir}/${profile}.${extension}" { inherit source; }
  ) profiles;

  assertion = {
    assertion = profiles ? ${defaultProfile};
    message = "${assistant}: auth.defaultProfile '${defaultProfile}' is not an enabled profile";
  };
}
