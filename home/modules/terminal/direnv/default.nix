# ==============================================================================
# Direnv (Auto-load .envrc per directory)
# ==============================================================================

{ pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    # Stable has -linkmode=external + CGO_ENABLED=0 breaking darwin (NixOS/nixpkgs#502769)
    package = pkgs.unstable.direnv;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    silent = true;
  };
}
