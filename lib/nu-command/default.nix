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

  # The shared Nushell modules, which a script `use`s by file name, such as `config-file.nu`.
  nuModules = lib.fileset.toSource {
    root = ../nu;
    fileset = lib.fileset.fileFilter (file: !(lib.hasSuffix ".test.nu" file.name)) ../nu;
  };
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
