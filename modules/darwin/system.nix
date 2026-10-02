# ==============================================================================
# macOS System Settings
# ==============================================================================

{
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
}
