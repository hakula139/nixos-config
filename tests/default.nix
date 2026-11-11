# ==================================================================================================
# Checks
# ==================================================================================================

{
  pkgs,
  repoLib,
}:

{
  nu-command = import ./nu-command { inherit pkgs repoLib; };
  scripts = import ./scripts {
    inherit pkgs repoLib;
    root = ../.;
  };
}
