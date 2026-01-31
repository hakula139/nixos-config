{
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Nix Configuration (for standalone Home Manager)
# ==============================================================================

let
  isLinux = pkgs.stdenv.isLinux;
in
{
  home.file.".config/nix/nix.conf" = lib.mkIf (isLinux && !isNixOS) {
    source = ./nix.conf;
  };
}
