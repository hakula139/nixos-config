{
  pkgs,
  lib,
  inputs,
  isNixOS ? false,
  isDesktop ? false,
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
    ./modules/fonts
    ./modules/git
    ./modules/mihomo
    ./modules/nix
    ./modules/ssh
    ./modules/syncthing
    ./modules/wakatime
    ./modules/zsh
  ];

  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home = {
    username = lib.mkDefault "hakula";
    homeDirectory = lib.mkDefault (if isDarwin then "/Users/hakula" else "/home/hakula");
    stateVersion = lib.mkDefault "25.11";
  };

  # ----------------------------------------------------------------------------
  # XDG Base Directories
  # ----------------------------------------------------------------------------
  xdg.enable = lib.mkDefault true;

  # ----------------------------------------------------------------------------
  # Generic Linux Settings (for non-NixOS systems)
  # ----------------------------------------------------------------------------
  targets.genericLinux.enable = lib.mkDefault (isLinux && !isNixOS);

  # ----------------------------------------------------------------------------
  # Home Manager Self-Management
  # ----------------------------------------------------------------------------
  programs.home-manager.enable = lib.mkDefault true;

  # ----------------------------------------------------------------------------
  # Custom Modules
  # ----------------------------------------------------------------------------
  hakula.claude-code = {
    enable = lib.mkDefault false;
    auth.useOAuthToken = lib.mkDefault false;
    proxy.enable = lib.mkDefault false;
  };

  hakula.cursor = {
    enable = lib.mkDefault true;
    extensions = {
      enable = lib.mkDefault isDesktop;
      prune = lib.mkDefault true;
    };
  };

  hakula.mihomo.enable = lib.mkDefault false;
}
