# ==================================================================================================
# File Formatter
# ==================================================================================================

{
  pkgs,
  repoLib,
}:

repoLib.mkNuCommand {
  inherit pkgs;
  name = "file-formatter";
  script = ./file-formatter.nu;

  runtimeInputs = [
    pkgs.direnv
    pkgs.git
    pkgs.prek
  ];
}
