# ==============================================================================
# Hakula's Home Manager Configuration
# ==============================================================================

{
  pkgs,
  lib,
  inputs,
  username ? "hakula",
  isDesktop ? false,
  isNixOS ? false,
  ...
}:

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
    inputs.listenbrainz-scrobbler.homeManagerModules.default

    ./modules/shared.nix
    ./modules/darwin.nix
    ./modules/wsl.nix
    ./modules/stale-links.nix
    ./modules/fonts
    ./modules/git
    ./modules/llm-assistants
    ./modules/mihomo
    ./modules/nix
    ./modules/secrets
    ./modules/ssh
    ./modules/syncthing
    ./modules/terminal
    ./modules/wakatime
    ./modules/corp-mirrors
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
  };

  hakula.nix.configPath = lib.mkDefault "${homeDir}/gitlab/nixos-config";
}
