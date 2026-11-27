# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  inputs,
  repoLib,
}:

{
  nu-command = import ./nu-command { inherit pkgs repoLib; };
  scripts = import ./scripts {
    inherit pkgs inputs repoLib;
    root = ../.;
  };
}
