# modules/darwin/system.nix — macOS system defaults (dock, finder, loginwindow)
# From config/flake.nix:99-107 — values your Mac already uses.
{ config, ... }: {
  system.stateVersion = 5;

  nixpkgs.hostPlatform = "aarch64-darwin"; # from inventory.json — per-host override in hosts/*/default.nix

  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      # Hide competing macOS spaces swipe indicators — AeroSpace owns workspaces
      expose-group-by-app = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
    };
    loginwindow.LoginwindowText = config.omanix.user;
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPasswordDelay = 10;
    NSGlobalDomain = {
      # Hide native menu bar so SketchyBar is the only bar (no competition)
      _HIHideMenuBar = true;
      # Also disable swipe between pages/fullscreen (AeroSpace owns navigation)
      AppleEnableSwipeNavigateWithScrolls = false;
    };
    CustomSystemPreferences = {
      "com.apple.dock" = {
        # Ensure menu bar stays hidden even after updates
        autohide-delay = 0.0;
      };
    };
  };
}
