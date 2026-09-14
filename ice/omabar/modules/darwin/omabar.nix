# modules/darwin/omabar.nix — Omanix Omabar: status items INSIDE the native macOS menu bar
# Launches the app in "--omabar" mode at login, which installs the Omabar status items
# (clock, battery, volume, Wi-Fi, running apps) into Apple's real menu bar via NSStatusItem.
# No bar is replaced, hidden, or restyled — the macOS menu bar stays as-is. When an Omabar
# item covers the same thing as a native Control Center item (clock/battery/sound/wifi),
# the corresponding native item is hidden so we don't show it twice.
# Controlled declaratively from themes/options.nix:
#   omanix.omabar.*   (enable, showClock, showBattery, showVolume, showWifi, showApps)
{ config, lib, pkgs, ... }:
{
  # Launch the Omanix app in "Omabar module mode" at login, restarted if it dies.
  # Runs as a PER-USER agent (launchd.user.agents, same as services.nix) so the
  # module shares the GUI's Accessibility permission instead of needing its own
  # root grant. NOTE: on the pinned nix-darwin (52d0615) launchd.*.agents.<name>
  # only takes serviceConfig — there is no top-level `enable`/`runAtLoad`
  # `keepAlive`/`program`/`args`, so gating is done at eval time with lib.mkIf.
  launchd.user.agents.omabar = lib.mkIf config.omanix.omabar.enable {
    serviceConfig = {
      Label = "om.omanix.omabar";
      ProgramArguments = [ "/Applications/Omanix.app/Contents/MacOS/Omanix" "--omabar" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # Hide the native Control Center status items that an enabled Omabar item replaces.
  # These are the same com.apple.controlcenter prefs the System Settings → Control Center
  # pane toggles. Built conditionally at eval time so the rendered script has no constant
  # conditionals (shellcheck SC2050 → build failure).
  system.activationScripts.postActivation.text = lib.mkAfter (
    (lib.optionalString (config.omanix.omabar.enable && config.omanix.omabar.showClock) ''
      defaults write com.apple.controlcenter "NSStatusItem Visible Clock" -bool false 2>/dev/null || true
    '') +
    (lib.optionalString (config.omanix.omabar.enable && config.omanix.omabar.showBattery) ''
      defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false 2>/dev/null || true
    '') +
    (lib.optionalString (config.omanix.omabar.enable && config.omanix.omabar.showVolume) ''
      defaults write com.apple.controlcenter "NSStatusItem Visible Sound" -bool false 2>/dev/null || true
    '') +
    (lib.optionalString (config.omanix.omabar.enable && config.omanix.omabar.showWifi) ''
      defaults write com.apple.controlcenter "NSStatusItem Visible WiFi" -bool false 2>/dev/null || true
    '') +
    # Apply the Control Center visibility changes when anything above changed.
    (lib.optionalString (config.omanix.omabar.enable && (config.omanix.omabar.showClock || config.omanix.omabar.showBattery || config.omanix.omabar.showVolume || config.omanix.omabar.showWifi)) ''
      killall ControlCenter 2>/dev/null || true
    '') +
    # Desktop navigation defaults. This always-block is inherited from the old desktop.nix
    # (swipe/grouping friction regardless of bar state) and kept as-is.
    ''
      defaults write -g AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
      defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
      defaults write com.apple.dock expose-group-by-app -bool false 2>/dev/null || true
      killall SystemUIServer 2>/dev/null || true
      killall Dock 2>/dev/null || true
    ''
  );
}