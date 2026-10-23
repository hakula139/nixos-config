# ==================================================================================================
# Auth Profile Switcher
# ==================================================================================================

{
  pkgs,
  lib,
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
  json = pkgs.formats.json { };
  profilesDir = "${stateDir}/profiles";

  switchConfig = json.generate "${name}.json" {
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
in
{
  package = pkgs.writers.writeNuBin name {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.coreutils ])

      "--add-flag"
      "${switchConfig}"
    ];
  } (builtins.readFile ./profile-switch.nu);

  files = lib.mapAttrs' (
    profile: source: lib.nameValuePair "${profilesDir}/${profile}.${extension}" { inherit source; }
  ) profiles;

  assertion = {
    assertion = profiles ? ${defaultProfile};
    message = "${assistant}: auth.defaultProfile '${defaultProfile}' is not an enabled profile";
  };
}
