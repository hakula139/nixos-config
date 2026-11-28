# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  inputs,
  repoLib,
}:

{
  editor-configs = import ./editor-configs {
    inherit pkgs;
    inherit (inputs) devkit;
  };
  nu-command = import ./nu-command { inherit pkgs repoLib; };
  scripts = import ./scripts {
    inherit pkgs inputs repoLib;
    root = ../.;
  };
}
