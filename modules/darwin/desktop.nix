# modules/darwin/desktop.nix — AeroSpace tiling + SketchyBar (mac-only)
# AeroSpace requires Accessibility permission — activation script guides user
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
in {
  # AeroSpace tiling window manager
  services.aerospace = {
    enable = true;
  };

  # SketchyBar status bar
  services.sketchybar = {
    enable = true;
  };

  # Activation script: check Accessibility permission and guide user
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Check if AeroSpace has Accessibility permission
    if ! /opt/homebrew/bin/aerospace --version >/dev/null 2>&1; then
      echo "AeroSpace installed but may need Accessibility permission."
    fi

    # Auto-open System Settings > Privacy > Accessibility on first switch
    if [ ! -f /tmp/.omanix-aerospace-permissions-checked ]; then
      echo ""
      echo "┌─────────────────────────────────────────────────────────┐"
      echo "│  AeroSpace needs Accessibility permission.             │"
      echo "│  Opening System Settings for you...                    │"
      echo "│  Click + and add AeroSpace, then close this window.    │"
      echo "└─────────────────────────────────────────────────────────┘"
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      touch /tmp/.omanix-aerospace-permissions-checked
    fi
  '';
}
