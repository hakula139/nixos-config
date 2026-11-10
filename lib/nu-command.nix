# ==================================================================================================
# Nushell Command
# ==================================================================================================

{
  lib,
  wrapPackage,
}:

{
  pkgs,
  name,
  script,
  runtimeInputs ? [ ],
  config ? null,
  flags ? { },
  substitutions ? { },
}:

let
  json = pkgs.formats.json { };

  wrapperFlags =
    lib.optionalAttrs (config != null) { config = json.generate "${name}.json" config; } // flags;

  placeholders = map (name: "@${name}@") (builtins.attrNames substitutions);

  values = map toString (builtins.attrValues substitutions);

  scriptText = builtins.replaceStrings placeholders values (builtins.readFile script);
in
wrapPackage {
  inherit pkgs;
  # `--help` names `main` after this file, which `makeWrapperArgs` would rename.
  pkg = pkgs.writers.writeNuBin name scriptText;

  wrapArgs =
    lib.optionals (runtimeInputs != [ ]) [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath runtimeInputs)
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (flag: value: [
        "--add-flag"
        "--${flag}"

        "--add-flag"
        "${value}"
      ]) wrapperFlags
    );
}
