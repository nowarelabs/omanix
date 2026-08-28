# modules/darwin/system.nix — macOS system defaults (dock, finder, loginwindow)
# From config/flake.nix:99-107 — values your Mac already uses.
{ config, ... }: {
  system.stateVersion = 5;

  nixpkgs.hostPlatform = "aarch64-darwin"; # from inventory.json — per-host override in hosts/*/default.nix

  system.defaults = {
    NSGlobalDomain = {
      _HIHideMenuBar = true;
      AppleEnableMouseSwipeNavigateWithScrolls = true;
      AppleEnableSwipeNavigateWithScrolls = false;
      AppleFontSmoothing = 2;
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleKeyboardUIMode = 3;
      AppleMeasurementUnits = "Centimeters";
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "Always";
      AppleTemperatureUnit = "Celsius";
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticWindowAnimationsEnabled = false;
      NSWindowShouldDragOnGesture = true;
      "com.apple.springing.delay" = 0.5;
      "com.apple.springing.enabled" = true;
      "com.apple.swipescrolldirection" = true;
      "com.apple.trackpad.forceClick" = false;
    };

    dock = {
      autohide = true;
      "autohide-delay" = 0.5;
      "autohide-time-modifier" = 0.2;
      "expose-group-apps" = false;
      largesize = 64;
      launchanim = false;
      magnification = false;
      mineffect = "scale";
      "minimize-to-application" = true;
      "mru-spaces" = false;
      orientation = "bottom";
      showMissionControlGestureEnabled = true;
      "show-process-indicators" = true;
      "show-recents" = false;
      tilesize = 48;
      "wvous-bl-corner" = 1;
      "wvous-br-corner" = 1;
      "wvous-tl-corner" = 1;
      "wvous-tr-corner" = 1;
    };

    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = false;
      CreateDesktop = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "clmv";
      FXRemoveOldTrashItems = true;
      NewWindowTarget = "Home";
      QuitMenuItem = true;
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowPathbar = true;
      ShowRemovableMediaOnDesktop = true;
      ShowStatusBar = true;
    };

    loginwindow.LoginwindowText = config.omanix.user;

    trackpad = {
      ActuateDetents = true;
      Clicking = true;
      DragLock = false;
      Dragging = false;
      TrackpadCornerSecondaryClick = 0;
      TrackpadFourFingerHorizSwipeGesture = 2;
      TrackpadFourFingerPinchGesture = 2;
      TrackpadFourFingerVertSwipeGesture = 2;
      TrackpadMomentumScroll = true;
      TrackpadPinch = true;
      TrackpadRightClick = true;
      TrackpadRotate = false;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerHorizSwipeGesture = 2;
      TrackpadThreeFingerTapGesture = 2;
      TrackpadThreeFingerVertSwipeGesture = 2;
      TrackpadTwoFingerDoubleTapGesture = false;
      TrackpadTwoFingerFromRightEdgeSwipeGesture = 3;
    };
  };

  system.defaults.CustomUserPreferences = {
    # Global keys not exposed as typed nix-darwin options
    NSGlobalDomain = {
      AppleAntiAliasingThreshold = 4;
      AppleMiniaturizeOnDoubleClick = false;
      "com.apple.sound.beep.flash" = false;
    };

    # Finder keys not exposed as typed nix-darwin options
    "com.apple.finder" = {
      FXArrangeGroupViewBy = "Name";
      FXICloudDriveDesktop = false;
      FXICloudDriveDocuments = false;
      FXICloudDriveEnabled = true;
      FXPreferredGroupBy = "Name";
      ShowSidebar = true;
    };

    # Trackpad keys not exposed as typed nix-darwin options
    "com.apple.AppleMultitouchTrackpad" = {
      TrackpadHorizScroll = true;
      TrackpadScroll = true;
      TrackpadHandResting = true;
      USBMouseStopsTrackpad = false;
      UserPreferences = true;
    };
  };
}
