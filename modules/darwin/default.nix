{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Darwin (macOS) Configuration
# ==============================================================================

let
  shared = import ../shared.nix { inherit pkgs; };
  keys = import ../../secrets/keys.nix;

  sshCfg = config.hakula.access.ssh;

  builder = {
    name = "CloudCone-US-2";
    ip = "74.48.189.161";
    port = 35060;
    sshUser = "root";
    sshKey = "${config.users.users.hakula.home}/.ssh/CloudCone/id_ed25519";
    system = "x86_64-linux";
    hostKey = keys.hosts.us-2;
  };
in
{
  imports = [
    ./ssh
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.access.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = builtins.attrValues keys.workstations;
      description = "SSH public keys authorized for user login";
    };
  };

  options.hakula.cachix = {
    enable = lib.mkEnableOption "Cachix auth token secret";
  };

  config = {
    # ----------------------------------------------------------------------------
    # Nix Configuration
    # ----------------------------------------------------------------------------
    nix = {
      enable = true;

      settings =
        shared.nixSettings
        // {
          extra-trusted-users = [ "hakula" ];
          builders-use-substitutes = true;
        }
        // lib.optionalAttrs config.hakula.cachix.enable {
          inherit (shared.cachix.caches) substituters trusted-public-keys;
        };

      distributedBuilds = true;
      buildMachines = [
        {
          hostName = builder.name;
          system = builder.system;
          protocol = "ssh-ng";
          sshUser = builder.sshUser;
          sshKey = builder.sshKey;
          maxJobs = 3;
          speedFactor = 2;
          supportedFeatures = [
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
        }
      ];

      gc = {
        automatic = true;
        interval = {
          Weekday = 0; # Sunday
          Hour = 2;
          Minute = 0;
        };
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
    };

    nixpkgs.config.allowUnfree = true;

    # ----------------------------------------------------------------------------
    # System Settings (best effort)
    # ----------------------------------------------------------------------------
    system = {
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = false;
      };

      defaults = {
        # ------------------------------------------------------------------------
        # NSGlobalDomain (system-wide preferences)
        # ------------------------------------------------------------------------
        NSGlobalDomain = {
          # Appearance → Show scroll bars
          AppleShowScrollBars = "WhenScrolling";

          # Keyboard → Key repeat
          ApplePressAndHoldEnabled = false;
          InitialKeyRepeat = 15;
          KeyRepeat = 2;

          # Keyboard → Keyboard navigation
          AppleKeyboardUIMode = 3;

          # Keyboard → Keyboard Shortcuts → Function Keys
          "com.apple.keyboard.fnState" = true;

          # Keyboard → Text Input
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = true;

          # Trackpad → Scroll & Zoom → Natural scrolling
          "com.apple.swipescrolldirection" = true;

          # Save / Print dialogs (Internal)
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
          PMPrintingExpandedStateForPrint = true;
          PMPrintingExpandedStateForPrint2 = true;
        };

        # ------------------------------------------------------------------------
        # Desktop & Dock
        # ------------------------------------------------------------------------
        dock = {
          # Dock
          tilesize = 55;
          magnification = true;
          largesize = 82;
          orientation = "bottom";
          minimize-to-application = true;
          autohide = true;
          show-recents = true;

          # Mission Control
          mru-spaces = true;
        };

        WindowManager = {
          # Desktop
          EnableStandardClickToShowDesktop = false;
          HideDesktop = false;

          # Stage Manager
          GloballyEnabled = false;
          AutoHide = false;
          AppWindowGroupingBehavior = true;

          # Widgets
          StandardHideWidgets = false;
          StageManagerHideWidgets = false;

          # Windows
          EnableTopTilingByEdgeDrag = true;
          EnableTiledWindowMargins = false;
        };

        # ------------------------------------------------------------------------
        # Menu Bar
        # ------------------------------------------------------------------------
        menuExtraClock = {
          # Clock Options
          ShowDate = 1;
          ShowDayOfMonth = true;
          ShowDayOfWeek = true;
          IsAnalog = false;
          FlashDateSeparators = false;
          ShowSeconds = false;
          Show24Hour = true;
        };

        # ------------------------------------------------------------------------
        # Keyboard
        # ------------------------------------------------------------------------
        hitoolbox = {
          # Press Fn key to
          AppleFnUsageType = "Change Input Source";
        };

        # ------------------------------------------------------------------------
        # Trackpad
        # ------------------------------------------------------------------------
        trackpad = {
          # Point & Click
          TrackpadRightClick = true;
          Clicking = true;

          # Accessibility → Pointer Control → Trackpad Options → Dragging style
          TrackpadThreeFingerDrag = true;
        };

        # ------------------------------------------------------------------------
        # Activity Monitor
        # ------------------------------------------------------------------------
        ActivityMonitor = {
          OpenMainWindow = true;
          ShowCategory = 101;
        };

        # ------------------------------------------------------------------------
        # Finder
        # ------------------------------------------------------------------------
        finder = {
          # General
          ShowHardDrivesOnDesktop = false;
          ShowExternalHardDrivesOnDesktop = false;
          ShowRemovableMediaOnDesktop = false;
          ShowMountedServersOnDesktop = false;
          NewWindowTarget = "Home";

          # Advanced
          AppleShowAllExtensions = true;
          FXEnableExtensionChangeWarning = false;
          _FXSortFoldersFirst = true;
          _FXSortFoldersFirstOnDesktop = false;
          FXDefaultSearchScope = "SCcf";

          # Internal
          QuitMenuItem = true;
          AppleShowAllFiles = false;
          ShowPathbar = true;
          ShowStatusBar = false;
          FXPreferredViewStyle = "Nlsv";
        };

        # ------------------------------------------------------------------------
        # Calendar
        # ------------------------------------------------------------------------
        iCal = {
          "first day of week" = "Monday";
          "TimeZone support enabled" = true;
        };

        # ------------------------------------------------------------------------
        # Custom User Preferences (not yet supported by nix-darwin)
        # ------------------------------------------------------------------------
        CustomUserPreferences = {
          # ----------------------------------------------------------------------
          # NSGlobalDomain (system-wide preferences)
          # ----------------------------------------------------------------------
          NSGlobalDomain = {
            # Menu Bar → Show menu bar background
            SLSMenuBarUseBlurredAppearance = true;
          };
        };
      };
    };

    # ----------------------------------------------------------------------------
    # Users & Security
    # ----------------------------------------------------------------------------
    users.users.hakula = {
      name = "hakula";
      home = "/Users/hakula";
      openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
    };

    system.primaryUser = "hakula";

    security.pam.services.sudo_local.touchIdAuth = true;

    # ----------------------------------------------------------------------------
    # SSH Configuration (system-wide)
    # ----------------------------------------------------------------------------
    programs.ssh.extraConfig = ''
      Host ${builder.name}
        HostName ${builder.ip}
        Port ${toString builder.port}
        User ${builder.sshUser}
        IdentityFile ${builder.sshKey}
    '';

    programs.ssh.knownHosts = {
      ${builder.name} = {
        extraHostNames = [
          builder.ip
          "[${builder.ip}]:${toString builder.port}"
        ];
        publicKey = builder.hostKey;
      };
    };

    # ----------------------------------------------------------------------------
    # Shell & Environment
    # ----------------------------------------------------------------------------
    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];

    # ----------------------------------------------------------------------------
    # Fonts & Packages
    # ----------------------------------------------------------------------------
    fonts.packages = shared.fonts;
    environment.systemPackages = shared.basePackages;

    # ----------------------------------------------------------------------------
    # Homebrew
    # ----------------------------------------------------------------------------
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        cleanup = "uninstall";
        upgrade = true;
      };
      taps = [ ];
      brews = [ ];
      casks = [
        "keyclu"
        "mos"
        "rectangle"
        "tailscale"
        "warp"
      ];
      masApps = { };
    };
  };
}
