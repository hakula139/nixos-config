{ pkgs, ... }:

{
  # ============================================================================
  # Nix Settings
  # ============================================================================
  nix = {
    # Enable flakes and new nix command
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Avoid unwanted garbage collection when using nix-direnv
      keep-outputs = true;
      keep-derivations = true;
    };

    # Garbage collection
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };

    # Let nix-darwin manage the Nix installation
    enable = true;
  };

  # ============================================================================
  # System Settings
  # ============================================================================
  system = {
    # Used for backwards compatibility
    stateVersion = 6;

    # Keyboard settings
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
    };

    # macOS system defaults
    defaults = {
      # Global settings
      NSGlobalDomain = {
        # Expand save panel by default
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;

        # Expand print panel by default
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;

        # Disable automatic capitalization
        NSAutomaticCapitalizationEnabled = false;

        # Disable smart dashes / quotes
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;

        # Enable full keyboard access for all controls
        AppleKeyboardUIMode = 3;

        # Fast key repeat
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };

      # Dock settings
      dock = {
        autohide = true;
        show-recents = false;
        mru-spaces = false;
        minimize-to-application = true;
      };

      # Finder settings
      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
      };

      # Trackpad settings
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };

  # ============================================================================
  # Shell Configuration
  # ============================================================================
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  # ============================================================================
  # Fonts
  # ============================================================================
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  # ============================================================================
  # Homebrew Integration
  # nix-darwin can manage Homebrew packages declaratively
  # ============================================================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      # "none" = don't remove anything
      # "uninstall" = remove unlisted brews / casks
      # "zap" = uninstall + remove all app data
      cleanup = "none";
      upgrade = true;
    };

    # Homebrew taps
    taps = [
    ];

    # CLI tools (prefer Nix when available)
    brews = [
    ];

    # GUI applications (casks)
    casks = [
    ];

    # Mac App Store apps (requires `mas` CLI)
    masApps = {
    };
  };

  # ============================================================================
  # Security
  # ============================================================================
  security.pam.services.sudo_local.touchIdAuth = true;

  # ============================================================================
  # System Packages
  # ============================================================================
  environment.systemPackages = with pkgs; [
    curl
    git
    vim

    # Nix tooling
    nil
    nixfmt-rfc-style
  ];
}
