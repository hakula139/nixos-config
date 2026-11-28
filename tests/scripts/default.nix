# ==================================================================================================
# Script Tests
# ==================================================================================================

{
  pkgs,
  inputs,
  repoLib,
  root,
}:

(inputs.devkit.lib.mkLib pkgs).nuTests {
  src = root;
  libDirs = [
    repoLib.nuTestLib
    repoLib.devkitNuLibDir
  ];
}
