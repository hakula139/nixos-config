{ pkgs, ... }:

{
  imports = [
    ./modules/zsh.nix
  ];

  # ============================================================================
  # Home Manager Settings
  # ============================================================================
  home = {
    username = "hakula";
    homeDirectory = "/home/hakula";
    stateVersion = "25.05";

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    packages = with pkgs; [
      # Modern CLI replacements
      eza # ls replacement with icons and git integration
      bat # cat replacement with syntax highlighting
      fd # find replacement, faster and user-friendly
      ripgrep # grep replacement, very fast

      # Fuzzy finding and smart navigation
      fzf # Command-line fuzzy finder
      zoxide # Smarter cd that learns your habits

      # System monitoring
      btop # Modern resource monitor

      # Archive tools
      unzip
      p7zip
    ];
  };

  # ============================================================================
  # Home Manager Self-Management
  # ============================================================================
  programs.home-manager.enable = true;
}
