# modules/darwin/omabar.nix — Omanix Omabar: native SwiftUI menu bar module (inside the Omanix app)
# Registers the bar Nerd Font system-wide, launches the app in "--omabar" mode at login,
# and applies the menu-bar defaults. Controlled declaratively from themes/options.nix:
#   omanix.omabar.*   (enable, position, height, transparent, blur, style, colorScheme, show*)
{ config, lib, pkgs, ... }:
{
  # Register the bar font system-wide (CoreText/Font Book) so the SwiftUI app can use
  # .custom("JetBrainsMono Nerd Font", ...). Ungated — the font is harmless when the bar is off.
  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  # Launch the Omanix app in "Omabar module mode" at login, restarted if it dies.
  # NOTE: on the pinned nix-darwin (52d0615) launchd.agents.<name> only takes serviceConfig —
  # there is no top-level `enable`/`runAtLoad`/`keepAlive`/`program`/`args` option here, so
  # gating is done at eval time with lib.mkIf (matches the postActivation pattern below).
  launchd.agents.omabar = lib.mkIf config.omanix.omabar.enable {
    serviceConfig = {
      Label = "om.omanix.omabar";
      ProgramArguments = [ "/Applications/Omanix.app/Contents/MacOS/Omanix" "--omabar" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # Menu-bar defaults. Built conditionally at eval time so the rendered activation script
  # has no constant conditionals (shellcheck SC2050 → build failure). The always-block is
  # inherited from the old desktop.nix (swipe/grouping friction regardless of bar state).
  system.activationScripts.postActivation.text = lib.mkAfter (
    (lib.optionalString config.omanix.omabar.enable ''
      # Hide the native macOS menu bar so Omanix's Omabar is the only bar
      defaults write NSGlobalDomain _HIHideMenuBar -bool true 2>/dev/null || true
      killall ControlCenter 2>/dev/null || true
      killall SystemUIServer 2>/dev/null || true
    '') +
    # Disable competing swipe/sidebar navigation regardless of menu-bar state
    ''
      defaults write -g AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
      defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
      defaults write com.apple.dock expose-group-by-app -bool false 2>/dev/null || true
      killall SystemUIServer 2>/dev/null || true
      killall Dock 2>/dev/null || true
    ''
  );
}