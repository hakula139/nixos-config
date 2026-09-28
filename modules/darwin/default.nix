# ==============================================================================
# Darwin (macOS) Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  caches,
  defaults,
  keys,
  repoLib,
  servers,
  ...
}:

let
  packages = repoLib.packagesFor pkgs;
  userName = config.hakula.user.name;
  homeConfig = config.home-manager.users.${userName} or { };
  userConfig = {
    name = userName;
    home = config.users.users.${userName}.home or "/Users/${userName}";
  };
  sshCfg = config.hakula.access.ssh;
  serverList = lib.attrValues servers;
in
{
  imports = [
    ./corp-tunnel
    ./llm-assistants
    ./ssh
    ./tailscale
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.access.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.attrValues keys.workstations;
      description = "SSH public keys authorized for user login";
    };
  };

  options.hakula.cachix = {
    enable = lib.mkEnableOption "Cachix auth token secret";
  };

  options.hakula.user.name = lib.mkOption {
    type = lib.types.str;
    default = "hakula";
    description = "Primary user account name";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.identityPaths = [ "${userConfig.home}/.ssh/id_ed25519" ];

    age.secrets = {
      builder-ssh-key = repoLib.secrets.mkSecret {
        name = "builders/ssh-key";
        owner = userName;
        group = "staff";
      };
    }
    // repoLib.secrets.mkRequiredUserSecrets {
      inherit homeConfig userConfig;
      group = "staff";
    };

    # --------------------------------------------------------------------------
    # Nix Configuration
    # --------------------------------------------------------------------------
    nix = {
      enable = true;

      settings =
        defaults.nixSettings
        // {
          extra-trusted-users = [ "hakula" ];
          builders-use-substitutes = true;
        }
        // lib.optionalAttrs config.hakula.cachix.enable {
          inherit (caches) substituters trusted-public-keys;
        };

      distributedBuilds = true;
      buildMachines = repoLib.ssh.mkBuildMachines serverList config.age.secrets.builder-ssh-key.path;

      gc = {
        automatic = true;
        interval = {
          Weekday = 0; # Sunday
          Hour = 2;
          Minute = 0;
        };
        options = "--delete-older-than 7d";
      };
      optimise.automatic = true;
    };

    nixpkgs.config.allowUnfree = true;

    # --------------------------------------------------------------------------
    # Environment
    # --------------------------------------------------------------------------
    launchd.user.envVariables.PATH = [
      "${userConfig.home}/.nix-profile/bin"
      "/etc/profiles/per-user/${userName}/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ];

    # --------------------------------------------------------------------------
    # System Settings (best effort)
    # --------------------------------------------------------------------------
    system = {
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = false;
      };

      defaults = {
        # ----------------------------------------------------------------------
        # NSGlobalDomain (system-wide preferences)
        # ----------------------------------------------------------------------
        NSGlobalDomain = {
          # Appearance
          AppleInterfaceStyle = "Dark";
          AppleShowScrollBars = "WhenScrolling";

          # Desktop & Dock → Windows
          AppleWindowTabbingMode = "always";

          # Desktop & Dock → Mission Control
          AppleSpacesSwitchOnActivate = true;

          # General → Language & Region
          AppleICUForce24HourTime = true;
          AppleMeasurementUnits = "Centimeters";
          AppleMetricUnits = 1;
          AppleTemperatureUnit = "Celsius";

          # Keyboard → Key repeat rate / Delay until repeat
          KeyRepeat = 2;
          InitialKeyRepeat = 15;

          # Keyboard → Keyboard navigation
          AppleKeyboardUIMode = 3;

          # Keyboard → Keyboard Shortcuts → Function Keys
          "com.apple.keyboard.fnState" = true;

          # Keyboard → Text Input → Edit
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = true;

          # Trackpad → Scroll & Zoom → Natural scrolling
          "com.apple.swipescrolldirection" = true;

          # Trackpad → More Gestures → Swipe between pages
          AppleEnableSwipeNavigateWithScrolls = false;

          # Keyboard press-and-hold accent menu (Internal)
          ApplePressAndHoldEnabled = false;

          # Save / Print dialogs (Internal)
          NSDocumentSaveNewDocumentsToCloud = false;
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
          PMPrintingExpandedStateForPrint = true;
          PMPrintingExpandedStateForPrint2 = true;
        };

        # ----------------------------------------------------------------------
        # Desktop & Dock
        # ----------------------------------------------------------------------
        dock = {
          # Desktop & Dock → Dock
          tilesize = 55;
          magnification = true;
          largesize = 82;
          orientation = "bottom";
          minimize-to-application = true;
          autohide = true;
          show-recents = true;

          # Desktop & Dock → Mission Control
          mru-spaces = false;
          expose-group-apps = true;

          # Desktop & Dock → Hot Corners
          wvous-tl-corner = 1;
          wvous-tr-corner = 2;
          wvous-bl-corner = 11;
          wvous-br-corner = 3;
        };

        WindowManager = {
          # Desktop & Dock → Desktop & Stage Manager
          HideDesktop = false;
          EnableStandardClickToShowDesktop = false;
          GloballyEnabled = false;
          AutoHide = false;
          AppWindowGroupingBehavior = true;

          # Desktop & Dock → Widgets
          StandardHideWidgets = false;
          StageManagerHideWidgets = false;

          # Desktop & Dock → Windows
          EnableTopTilingByEdgeDrag = true;
          EnableTiledWindowMargins = false;
        };

        # ----------------------------------------------------------------------
        # Keyboard
        # ----------------------------------------------------------------------
        hitoolbox = {
          # Keyboard → Press Fn key to
          AppleFnUsageType = "Change Input Source";
        };

        # ----------------------------------------------------------------------
        # Menu Bar
        # ----------------------------------------------------------------------
        menuExtraClock = {
          # Menu Bar → Menu Bar Controls → Clock Options
          ShowDate = 1;
          ShowDayOfMonth = true;
          ShowDayOfWeek = true;
          IsAnalog = false;
          Show24Hour = true;
          FlashDateSeparators = false;
          ShowSeconds = false;
        };

        # ----------------------------------------------------------------------
        # Trackpad
        # ----------------------------------------------------------------------
        trackpad = {
          # Trackpad → Point & Click
          TrackpadRightClick = true;
          Clicking = true;

          # Accessibility → Pointer Control → Trackpad Options → Dragging style
          TrackpadThreeFingerDrag = true;
        };

        # ----------------------------------------------------------------------
        # Users & Groups
        # ----------------------------------------------------------------------
        loginwindow = {
          # Users & Groups → Guest User
          GuestEnabled = false;
        };

        # ----------------------------------------------------------------------
        # Activity Monitor
        # ----------------------------------------------------------------------
        ActivityMonitor = {
          # Activity Monitor → View → All Processes, Hierarchically
          ShowCategory = 101;

          # Activity Monitor startup window (Internal)
          OpenMainWindow = true;
        };

        # ----------------------------------------------------------------------
        # Calendar
        # ----------------------------------------------------------------------
        iCal = {
          # Calendar → Settings → General → Start week on
          "first day of week" = "Monday";

          # Calendar → Settings → Advanced → Turn on time zone support
          "TimeZone support enabled" = true;
        };

        # ----------------------------------------------------------------------
        # Finder
        # ----------------------------------------------------------------------
        finder = {
          # Finder → Settings → General
          ShowHardDrivesOnDesktop = false;
          ShowExternalHardDrivesOnDesktop = false;
          ShowRemovableMediaOnDesktop = false;
          ShowMountedServersOnDesktop = false;
          NewWindowTarget = "Home";

          # Finder → Settings → Advanced
          AppleShowAllExtensions = true;
          FXEnableExtensionChangeWarning = false;
          FXRemoveOldTrashItems = true;
          _FXSortFoldersFirst = true;
          _FXSortFoldersFirstOnDesktop = false;
          FXDefaultSearchScope = "SCcf";

          # Finder → View
          FXPreferredViewStyle = "Nlsv";
          ShowPathbar = true;
          ShowStatusBar = false;

          # Finder hidden files / Quit menu item (Internal)
          AppleShowAllFiles = false;
          QuitMenuItem = true;
        };

        # ----------------------------------------------------------------------
        # Screenshots
        # ----------------------------------------------------------------------
        screencapture = {
          # Screenshot → Options → Save to
          location = "~/Pictures";
          target = "file";

          # Screenshot file format (Internal)
          type = "png";
        };

        # ----------------------------------------------------------------------
        # Custom User Preferences (not yet supported by nix-darwin)
        # ----------------------------------------------------------------------
        CustomUserPreferences = {
          # --------------------------------------------------------------------
          # NSGlobalDomain (system-wide preferences)
          # --------------------------------------------------------------------
          NSGlobalDomain = {
            # Menu Bar → Show menu bar background
            SLSMenuBarUseBlurredAppearance = true;
          };
        };
      };

      activationScripts.postActivation.text = ''
        pmset -a networkoversleep 1
        pmset -c sleep 0
      '';
    };

    # --------------------------------------------------------------------------
    # Users & Security
    # --------------------------------------------------------------------------
    users.users.hakula = {
      name = "hakula";
      home = "/Users/hakula";
      openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
    };

    system.primaryUser = "hakula";

    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };

    # Network → Firewall
    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
      allowSigned = false;
      allowSignedApp = false;
    };

    # --------------------------------------------------------------------------
    # SSH Configuration (system-wide)
    # --------------------------------------------------------------------------
    programs.ssh.extraConfig = repoLib.ssh.mkExtraConfig serverList config.age.secrets.builder-ssh-key.path;

    programs.ssh.knownHosts = repoLib.ssh.mkKnownHosts serverList;

    # --------------------------------------------------------------------------
    # Shell & Environment
    # --------------------------------------------------------------------------
    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];
    environment.variables = defaults.localeSettings;

    # --------------------------------------------------------------------------
    # Fonts & Packages
    # --------------------------------------------------------------------------
    fonts.packages = packages.fonts;
    environment.systemPackages = packages.base ++ [ pkgs.thaw ];

    # --------------------------------------------------------------------------
    # Homebrew
    # --------------------------------------------------------------------------
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = true;
        cleanup = "uninstall";
        extraFlags = [ "--force-cleanup" ];
        upgrade = true;
      };
      taps = [ ];
      brews = [ ];
      casks = [
        "keyclu"
        "mos"
        "onedrive"
        "rectangle"
        "warp"
      ];
      masApps = { };
    };
  };
}
