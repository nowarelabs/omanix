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
    trackpad = {
      TrackpadThreeFingerVertSwipeGesture = 2;
    };
  };
}
