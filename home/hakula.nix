{
  pkgs,
  lib,
  inputs,
  isNixOS ? false,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  imports = [
    inputs.agenix.homeManagerModules.default
    ./modules/shared.nix
    ./modules/darwin.nix
    ./modules/cursor
    ./modules/git.nix
    ./modules/ssh.nix
    ./modules/zsh.nix
  ];

  # ============================================================================
  # Home Manager Settings
  # ============================================================================
  home = {
    username = "hakula";
    homeDirectory = if isDarwin then "/Users/hakula" else "/home/hakula";
    stateVersion = "25.05";

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    packages = with pkgs; [
      # Modern CLI replacements
      eza
      bat
      fd
      ripgrep

      # Fuzzy finding and smart navigation
      fzf
      zoxide

      # System monitoring
      btop

      # Archive tools
      unzip
      p7zip
    ];
  };

  # ============================================================================
  # XDG Base Directories
  # ============================================================================
  xdg.enable = true;

  # ============================================================================
  # Generic Linux Settings (for non-NixOS systems)
  # ============================================================================
  targets.genericLinux.enable = lib.mkDefault (isLinux && !isNixOS);

  # ============================================================================
  # Home Manager Self-Management
  # ============================================================================
  programs.home-manager.enable = true;

  # ============================================================================
  # Custom Modules
  # ============================================================================
  hakula.cursor = {
    enable = true;

    extensions = {
      enable = true;
      prune = true;
    };
  };
}
