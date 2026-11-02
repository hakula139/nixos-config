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

  testsWith =
    suffix: lib.fileset.toList (lib.fileset.fileFilter (file: lib.hasSuffix suffix file.name) root);

  nuTests = testsWith ".test.nu";
  tsTests = testsWith ".test.ts";

  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions (map dirOf (nuTests ++ tsTests));
  };

  testPaths = map (lib.path.removePrefix root);
in
pkgs.runCommand "script-tests"
  {
    nativeBuildInputs = [
      pkgs.direnv
      pkgs.git
      pkgs.nixfmt
      pkgs.prek
      pkgs.zstd
      tooling.scriptPython
    ]
    ++ tooling.testRunners;
  }
  ''
    cd ${src}
    nu-test ${lib.escapeShellArgs (testPaths nuTests)}
    bun test ${lib.escapeShellArgs (testPaths tsTests)}
    touch "$out"
  ''
