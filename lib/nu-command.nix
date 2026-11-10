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
  makeWrapperArgs ? [ ],
}:

let
  json = pkgs.formats.json { };

  wrapperFlags =
    lib.optionalAttrs (config != null) { config = json.generate "${name}.json" config; } // flags;

  argumentGuard = builtins.readFile ./nu-wrapper.sh;
in
wrapPackage {
  inherit pkgs;
  # `--help` names `main` after this file, which `writeNuBin`'s `makeWrapperArgs` would rename.
  pkg = pkgs.writers.writeNuBin name (builtins.readFile script);

  wrapArgs = [
    "--run"
    argumentGuard
  ]
  ++ lib.optionals (runtimeInputs != [ ]) [
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
  )
  ++ makeWrapperArgs;
}
