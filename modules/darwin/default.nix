{ pkgs, ... }:

# ==============================================================================
# Darwin (macOS) Configuration
# ==============================================================================

let
  shared = import ../shared.nix { inherit pkgs; };
in
{
  # ============================================================================
  # Nix
  # ============================================================================
  nix = {
    enable = true;
    settings = shared.nixSettings;
    optimise.automatic = true;
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

  nixpkgs.config.allowUnfree = true;

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
      NSGlobalDomain = {
        AppleKeyboardUIMode = 3;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;
      };

      dock = {
        autohide = true;
        show-recents = true;
        mru-spaces = false;
        minimize-to-application = true;
      };

      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        FXEnableExtensionChangeWarning = false;
        QuitMenuItem = true;
        ShowPathbar = true;
        ShowStatusBar = false;
        _FXShowPosixPathInTitle = false;
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

  environment.systemPackages = shared.basePackages;

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
