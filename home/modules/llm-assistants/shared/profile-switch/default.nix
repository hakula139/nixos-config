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
  configFile ? null,
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
      configFile
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
