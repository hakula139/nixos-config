# ==================================================================================================
# File Formatter
# ==================================================================================================

{
  pkgs,
}:

let
  inherit (pkgs) lib;
in
pkgs.writers.writeNuBin "file-formatter" {
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      pkgs.direnv
      pkgs.git
      pkgs.prek
    ])
  ];
} (builtins.readFile ./file-formatter.nu)
