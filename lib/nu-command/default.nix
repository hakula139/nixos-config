# ==================================================================================================
# Nushell Command
# ==================================================================================================

{
  lib,
  devkit,
  nuModules,
}:

{
  pkgs,
  name,
  script,
  runtimeInputs ? [ ],
  libDirs ? [ ],
  config ? null,
  flags ? { },
  makeWrapperArgs ? [ ],
}:

let
  json = pkgs.formats.json { };

  wrapperFlags =
    lib.optionalAttrs (config != null) { config = json.generate "${name}.json" config; } // flags;

  dk = devkit.lib.mkLib pkgs;
in
dk.writeNuApplication {
  inherit
    name
    runtimeInputs
    makeWrapperArgs
    ;

  text = builtins.readFile script;
  libDirs = [ nuModules ] ++ libDirs;

  flags = wrapperFlags;
}
