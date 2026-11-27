# ==================================================================================================
# Script Tests
# ==================================================================================================

{
  pkgs,
  repoLib,
  root,
}:

let
  inherit (pkgs) lib;

  tooling = repoLib.toolingFor pkgs;

  nuTests = lib.fileset.toList (
    lib.fileset.fileFilter (file: lib.hasSuffix ".test.nu" file.name) root
  );

  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions (map dirOf nuTests);
  };

  testPaths = map (lib.path.removePrefix root);
in
pkgs.runCommand "script-tests"
  {
    env.NU_LIB_DIRS = "${repoLib.nuTestLib}";

    nativeBuildInputs = tooling.testRunners;
  }
  ''
    cd ${src}
    nu-test ${lib.escapeShellArgs (testPaths nuTests)}
    touch "$out"
  ''
