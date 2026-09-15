# ==============================================================================
# Server Deployment
# ==============================================================================

{
  pkgs,
  lib,
}:

let
  config = pkgs.writeText "deploy.json" (
    builtins.toJSON {
      caches = (import ../../data/caches.nix).substituters ++ [ "https://cache.nixos.org" ];
      servers = import ../../data/servers.nix;
    }
  );
in
pkgs.writers.writeNuBin "deploy" {
  makeWrapperArgs = [
    "--set"
    "NIXOS_DEPLOY_CONFIG"
    "${config}"
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      pkgs.colmena
      pkgs.coreutils
      pkgs.curl
      pkgs.git
      pkgs.gh
      pkgs.nix
      pkgs.openssh
    ])
  ];
} (builtins.readFile ./deploy.nu)
