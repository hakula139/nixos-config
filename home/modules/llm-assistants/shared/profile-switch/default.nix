# ==============================================================================
# Auth Profile Switcher
# ==============================================================================

{
  pkgs,
  lib,
}:

{
  name,
  assistant,
  profilesDir,
  extension,
  stateDir,
  defaultProfile,
  configFile ? null,
  defaultSettings ? { },
  resetKeys ? [ ],
}:

let
  json = pkgs.formats.json { };

  switchConfig = json.generate "${name}.json" {
    inherit
      assistant
      profilesDir
      extension
      stateDir
      defaultProfile
      configFile
      defaultSettings
      resetKeys
      ;
  };
in
pkgs.writers.writeNuBin name {
  makeWrapperArgs = [
    "--add-flag"
    "${switchConfig}"
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ pkgs.coreutils ])
  ];
} (builtins.readFile ./profile-switch.nu)
