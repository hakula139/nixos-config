{
  pkgs,
  lib,
  inputs,
  username ? "hakula",
  isNixOS ? false,
  isDesktop ? false,
  ...
}:

# ==============================================================================
# Hakula's Home Manager Configuration
# ==============================================================================

let
  inherit (pkgs.stdenv) isDarwin isLinux;

  homeDir =
    if isDarwin then
      "/Users/${username}"
    else if username == "root" then
      "/root"
    else
      "/home/${username}";
in
{
  imports = [
    inputs.agenix.homeManagerModules.default
    ./modules/shared.nix
    ./modules/darwin.nix
    ./modules/claude-code
    ./modules/codex
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
    inherit username;
    homeDirectory = lib.mkDefault homeDir;
    stateVersion = lib.mkDefault "25.11";
  };

  # ----------------------------------------------------------------------------
  # XDG Base Directories
  # ----------------------------------------------------------------------------
  xdg.enable = true;

  # ----------------------------------------------------------------------------
  # Generic Linux Settings (for non-NixOS systems)
  # ----------------------------------------------------------------------------
  targets.genericLinux.enable = isLinux && !isNixOS;

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
      enable = isDesktop;
      prune = true;
    };
    nixd.flakePath = if isDesktop then "${homeDir}/GitHub/nixos-config" else "${homeDir}/nixos-config";
  };
}
