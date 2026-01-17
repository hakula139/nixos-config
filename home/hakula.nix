{
  pkgs,
  lib,
  inputs,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Hakula's Home Manager Configuration
# ==============================================================================

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  imports = [
    inputs.agenix.homeManagerModules.default
    ./modules/shared.nix
    ./modules/darwin.nix
    ./modules/claude-code
    ./modules/cursor
    ./modules/git
    ./modules/ssh
    ./modules/syncthing
    ./modules/wakatime
    ./modules/zsh
  ];

  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home = {
    username = "hakula";
    homeDirectory = if isDarwin then "/Users/hakula" else "/home/hakula";
    stateVersion = "25.05";
  };

  # ----------------------------------------------------------------------------
  # XDG Base Directories
  # ----------------------------------------------------------------------------
  xdg.enable = true;

  # ----------------------------------------------------------------------------
  # Generic Linux Settings (for non-NixOS systems)
  # ----------------------------------------------------------------------------
  targets.genericLinux.enable = lib.mkDefault (isLinux && !isNixOS);

  # ----------------------------------------------------------------------------
  # Home Manager Self-Management
  # ----------------------------------------------------------------------------
  programs.home-manager.enable = true;

  # ----------------------------------------------------------------------------
  # Custom Modules
  # ----------------------------------------------------------------------------
  hakula.cursor = {
    enable = true;
    extensions = {
      enable = true;
      prune = true;
    };
  };
}
