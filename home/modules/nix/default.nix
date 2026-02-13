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
  inherit (pkgs.stdenv) isLinux;
  caches = import ../../../lib/caches.nix;

  nixConf = ''
    experimental-features = nix-command flakes
    extra-substituters = ${lib.concatStringsSep " " caches.substituters}
    extra-trusted-public-keys = ${lib.concatStringsSep " " caches.trusted-public-keys}
  '';
in
{
  home.file.".config/nix/nix.conf" = lib.mkIf (isLinux && !isNixOS) {
    text = nixConf;
  };
}
