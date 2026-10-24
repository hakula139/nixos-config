# ==================================================================================================
# Script Tests
# ==================================================================================================

{
  pkgs,
  root,
}:

let
  inherit (pkgs) lib;

  tooling = import ./tooling.nix { inherit pkgs; };

  tests = lib.fileset.toList (lib.fileset.fileFilter (file: lib.hasSuffix ".test.nu" file.name) root);

  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions ([ ./format-files.nu ] ++ map dirOf tests);
  };

  testPaths = map (test: lib.path.removePrefix root test) tests;
in
pkgs.runCommand "script-tests"
  {
    AUTO_FORMAT_DPRINT_CONFIG = "${tooling.markdownDprintConfigDir}/dprint.json";

    nativeBuildInputs = [
      pkgs.codex
      pkgs.dprint
      pkgs.git
      pkgs.nu-test
      tooling.scriptPython
    ];
  }
  ''
    cd ${src}
    nu-test ${lib.escapeShellArgs testPaths}
    touch "$out"
  ''
