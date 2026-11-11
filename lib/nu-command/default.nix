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
  inherit name runtimeInputs;

  text = builtins.readFile script;
  makeWrapperArgs =
    lib.concatLists (
      lib.mapAttrsToList (flag: value: [
        "--add-flag"
        "--${flag}"

        "--add-flag"
        (toString value)
      ]) wrapperFlags
    )
    ++ makeWrapperArgs;
}
