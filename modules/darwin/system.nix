# modules/darwin/system.nix — macOS system defaults (dock, finder, loginwindow)
# From config/flake.nix:99-107 — values your Mac already uses.
{ config, ... }: {
  system.stateVersion = 5;

  nixpkgs.hostPlatform = "aarch64-darwin"; # from inventory.json — per-host override in hosts/*/default.nix

  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
    };
    finder = {
      AppleShowAllExtensions = true;
      FXPreferredViewStyle = "clmv";
    };
    loginwindow.LoginwindowText = config.omanix.user;
    screencapture.location = "~/Pictures/screenshots";
    screensaver.askForPasswordDelay = 10;

    CustomSystemPreferences = {
      "com.apple.dock" = {
        # Ensure menu bar stays hidden even after updates
        autohide-delay = 0.0;
      };
    };
  };
}
