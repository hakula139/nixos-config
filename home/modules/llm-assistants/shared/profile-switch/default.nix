# ==============================================================================
# Auth Profile Switcher
# ==============================================================================

{
  pkgs,
  lib,
  name,
  assistant,
  profilesDir,
  extension,
  stateDir,
}:

let
  switchConfig = pkgs.writeText "${name}.json" (
    builtins.toJSON {
      inherit
        assistant
        profilesDir
        extension
        stateDir
        ;
    }
  );
in
pkgs.writers.writeNuBin name {
  makeWrapperArgs = [
    "--add-flag"
    switchConfig
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ pkgs.coreutils ])
  ];
} (builtins.readFile ./profile-switch.nu)
