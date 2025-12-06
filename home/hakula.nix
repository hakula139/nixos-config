{
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  imports = [
    ./modules/zsh.nix
    ./modules/git.nix
    ./modules/shared.nix
    ./modules/darwin.nix
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
  # XDG Base Directories
  # ============================================================================
  xdg.enable = true;

  # ============================================================================
  # Home Manager Self-Management
  # ============================================================================
  programs.home-manager.enable = true;
}
