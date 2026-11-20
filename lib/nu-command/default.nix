# ==================================================================================================
# Nushell Command
# ==================================================================================================

{
  lib,
  devkit,
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
    libDirs
    makeWrapperArgs
    ;

  text = builtins.readFile script;

  flags = wrapperFlags;
}
