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
    fileset = lib.fileset.unions (map dirOf tests);
  };

  testPaths = map (test: lib.path.removePrefix root test) tests;
in
pkgs.runCommand "script-tests"
  {
    PROXY_TEST_FIXTURES = import ./proxy-test-fixtures.nix { inherit pkgs; };

    nativeBuildInputs = [
      pkgs.file-formatter
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
