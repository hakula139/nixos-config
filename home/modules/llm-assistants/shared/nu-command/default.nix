# ==================================================================================================
# Nu Command
# ==================================================================================================
# Wraps a Nushell script into an executable that prepends its JSON config to caller arguments.
# ==================================================================================================

{
  pkgs,
  lib,
}:

let
  json = pkgs.formats.json { };
in
{
  name,
  script,
  config,
}:

let
  configFile = json.generate "${name}.json" config;
in
pkgs.writers.writeNuBin name {
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ pkgs.coreutils ])
    "--add-flag"
    "${configFile}"
  ];
} (builtins.readFile script)
