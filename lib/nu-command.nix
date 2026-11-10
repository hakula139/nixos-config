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

  # Nushell rebuilds the `main ...` line from argv without quoting `--` arguments.
  argumentGuard = ''
    for arg in "$@"; do
      if [[ "$arg" == --* && ! "$arg" =~ ^--[A-Za-z][A-Za-z0-9-]*$ ]]; then
        echo "${name}: unsupported argument: $arg" >&2
        exit 2
      fi
    done
  '';
in
wrapPackage {
  inherit pkgs;
  # `--help` names `main` after this file, which `makeWrapperArgs` would rename.
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
