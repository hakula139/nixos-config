# ==================================================================================================
# Hakula's Home Manager Configuration
# ==================================================================================================

{
  pkgs,
  lib,
  inputs,
  isDesktop,
  isNixOS,
  username,
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
    inputs.flake-catalog.homeModules.activity-report
    inputs.flake-catalog.homeModules.agent-project-move
    inputs.flake-catalog.homeModules.claude-statusline
    inputs.flake-catalog.homeModules.listenbrainz-scrobbler
    inputs.flake-catalog.homeModules.oxide-code

    ./modules/shared.nix
    ./modules/darwin.nix
    ./modules/wsl.nix
    ./modules/stale-links.nix
    ./modules/corp-mirrors
    ./modules/editor
    ./modules/fonts
    ./modules/git
    ./modules/llm-assistants
    ./modules/nix
    ./modules/rclone
    ./modules/secrets
    ./modules/ssh
    ./modules/terminal
    ./modules/wakatime
  ];

  # ------------------------------------------------------------------------------------------------
  # Home Manager Settings
  # ------------------------------------------------------------------------------------------------
  home = {
    inherit username;
    homeDirectory = lib.mkDefault homeDir;
    stateVersion = lib.mkDefault "25.11";
  };

  # ------------------------------------------------------------------------------------------------
  # XDG Base Directories
  # ------------------------------------------------------------------------------------------------
  xdg.enable = true;

  # ------------------------------------------------------------------------------------------------
  # Generic Linux Settings (for non-NixOS systems)
  # ------------------------------------------------------------------------------------------------
  targets.genericLinux.enable = isLinux && !isNixOS;

  # ------------------------------------------------------------------------------------------------
  # Home Manager Self-Management
  # ------------------------------------------------------------------------------------------------
  programs.home-manager.enable = true;

  # ------------------------------------------------------------------------------------------------
  # Custom Modules
  # ------------------------------------------------------------------------------------------------
  hakula.cursor = {
    enable = true;
    extensions = {
      enable = isDesktop;
      prune = true;
    };
  };

  hakula.zed.enable = true;

  hakula.nix.configPath = lib.mkDefault "${homeDir}/gitlab/nixos-config";
}
