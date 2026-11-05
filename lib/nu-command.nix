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
}:

let
  json = pkgs.formats.json { };

  wrapperFlags =
    lib.optionalAttrs (config != null) { config = json.generate "${name}.json" config; } // flags;
in
wrapPackage {
  inherit pkgs;
  # `--help` names `main` after this file, which `makeWrapperArgs` would rename.
  pkg = pkgs.writers.writeNuBin name (builtins.readFile script);

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
