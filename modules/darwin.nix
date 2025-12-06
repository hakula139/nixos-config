{ pkgs, ... }:

# ============================================================================
# Darwin (macOS) Configuration
# ============================================================================

let
  shared = import ./shared.nix { inherit pkgs; };
in
{
  # ============================================================================
  # Nix
  # ============================================================================
  nix = {
    enable = true; # Let nix-darwin manage the Nix installation
    settings = shared.nixSettings;
    gc = {
      automatic = true;
      interval = {
        Weekday = 0; # Sunday
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  # ============================================================================
  # System
  # ============================================================================
  system = {
    stateVersion = 6;

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
    };

    defaults = {
      # Global settings
      NSGlobalDomain = {
        # Expand save / print panels by default
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
        # Disable auto-capitalization and smart quotes / dashes
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        # Full keyboard access for all controls
        AppleKeyboardUIMode = 3;
        # Fast key repeat
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
      };

      dock = {
        autohide = true;
        show-recents = true;
        mru-spaces = false;
        minimize-to-application = true;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXShowPosixPathInTitle = true;
      };

      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };

  # ============================================================================
  # Security
  # ============================================================================
  security.pam.services.sudo_local.touchIdAuth = true;

  # ============================================================================
  # Environment
  # ============================================================================
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  fonts.packages = shared.fonts;

  environment.systemPackages = shared.basePackages ++ shared.nixTooling;

  # ============================================================================
  # Homebrew
  # ============================================================================
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "none"; # "uninstall" or "zap" to remove unlisted packages
      upgrade = true;
    };
    taps = [ ];
    brews = [ ];
    casks = [ ];
    masApps = { };
  };
}
