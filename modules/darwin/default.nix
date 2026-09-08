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

        # ----------------------------------------------------------------------
        # Desktop & Dock
        # ----------------------------------------------------------------------
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

        # ----------------------------------------------------------------------
        # Menu Bar
        # ----------------------------------------------------------------------
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

        # ----------------------------------------------------------------------
        # Keyboard
        # ----------------------------------------------------------------------
        hitoolbox = {
          # Press Fn key to
          AppleFnUsageType = "Change Input Source";
        };

        # ----------------------------------------------------------------------
        # Trackpad
        # ----------------------------------------------------------------------
        trackpad = {
          # Point & Click
          TrackpadRightClick = true;
          Clicking = true;

          # Accessibility → Pointer Control → Trackpad Options → Dragging style
          TrackpadThreeFingerDrag = true;
        };

        # ----------------------------------------------------------------------
        # Activity Monitor
        # ----------------------------------------------------------------------
        ActivityMonitor = {
          OpenMainWindow = true;
          ShowCategory = 101;
        };

        # ----------------------------------------------------------------------
        # Finder
        # ----------------------------------------------------------------------
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

        # ----------------------------------------------------------------------
        # Calendar
        # ----------------------------------------------------------------------
        iCal = {
          "first day of week" = "Monday";
          "TimeZone support enabled" = true;
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

    security.pam.services.sudo_local.touchIdAuth = true;

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
    environment.systemPackages = packages.base;

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
