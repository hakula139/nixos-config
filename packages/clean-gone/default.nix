# ==================================================================================================
# Clean Gone
# ==================================================================================================

{
  pkgs,
  repoLib,
}:

repoLib.mkNuCommand {
  inherit pkgs;
  name = "clean-gone";
  script = ./clean-gone.nu;

  runtimeInputs = [
    pkgs.git
    pkgs.lsof
    pkgs.openssh
  ];
}
