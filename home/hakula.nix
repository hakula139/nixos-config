# ==============================================================================
# Hakula's Home Manager Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpDomain,
  llmAssistantLib,
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
    ./modules/shared.nix
    ./modules/darwin.nix
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
    ./modules/wsl
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
  # Auto-import the shared profile library when a host opts in via `defaultProfile`.
  # The corp-gateway profile is gated on `enableCorpGateway` so servers (which
  # can't decrypt its secrets) stay on the public subset.
  hakula.claude-code.auth.profiles =
    lib.mkIf (config.hakula.claude-code.auth.defaultProfile != null)
      (
        llmAssistantLib.mkClaudeProfiles {
          inherit lib corpDomain;
          inherit (config.hakula.claude-code.auth) enableCorpGateway;
        }
      );

  hakula.cursor = {
    enable = true;
    extensions = {
      enable = isDesktop;
      prune = true;
    };
    nixd.flakePath = lib.mkDefault "${homeDir}/nixos-config";
  };
}
