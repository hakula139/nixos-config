# ==================================================================================================
# Script Tests
# ==================================================================================================
# Each `*.test.nu` file runs under `nu-test` with the files beside it, which hold its subject.
# ==================================================================================================

{
  pkgs,
  root,
}:

let
  inherit (pkgs) lib;

  tests = lib.fileset.toList (lib.fileset.fileFilter (file: lib.hasSuffix ".test.nu" file.name) root);

  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions (map dirOf tests);
  };

  testPaths = map (test: lib.path.removePrefix root test) tests;
in
pkgs.runCommand "script-tests"
  {
    nativeBuildInputs = [
      pkgs.nu-test
      (pkgs.python3.withPackages (ps: [ ps.jinja2 ]))
    ];
  }
  ''
    export HOME="$TMPDIR"
    cd ${src}
    nu-test ${lib.escapeShellArgs testPaths}
    touch "$out"
  ''
