# ==================================================================================================
# Script Tests
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
      pkgs.git
      pkgs.nu-test
      (pkgs.python3.withPackages (ps: [ ps.jinja2 ]))
    ];
  }
  ''
    cd ${src}
    nu-test ${lib.escapeShellArgs testPaths}
    touch "$out"
  ''
