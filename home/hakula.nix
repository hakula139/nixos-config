# ==============================================================================
# Hakula's Home Manager Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  username ? "hakula",
  isNixOS ? false,
  isDesktop ? false,
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
    inputs.agenix.homeManagerModules.default
    ./modules/shared.nix
    ./modules/darwin.nix
    ./modules/fonts
    ./modules/git
    ./modules/llm-assistants
    ./modules/mihomo
    ./modules/nix
    ./modules/ssh
    ./modules/syncthing
    ./modules/terminal
    ./modules/wakatime
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
  # Hosts that opt in by setting `defaultProfile` get the shared public profile
  # library. Corp-capable hosts (workstations + hakula-devvm) additionally merge
  # in `lib/claude-profiles-corp.nix` to layer the corp-gateway profile on top —
  # servers cannot decrypt its secrets and must stay on the public subset.
  hakula.claude-code.auth.profiles = lib.mkIf (
    config.hakula.claude-code.auth.defaultProfile != null
  ) (lib.mkDefault (import ../lib/claude-profiles.nix));

  hakula.cursor = {
    enable = true;
    extensions = {
      enable = isDesktop;
      prune = true;
    };
    nixd.flakePath = lib.mkDefault "${homeDir}/nixos-config";
  };
}
