# modules/darwin/spacebar.nix — Omanix Spacebar: full-width status bar OUTSIDE the native macOS menu bar
# Replaces the old in-menu-bar Omabar with the external `spacebar` daemon
# (github.com/cmacrae/spacebar, nixpkgs pkg 1.4.0). spacebar draws its own bar just
# below the native menu bar (position "top") or at the screen bottom, using native
# Mission Control APIs for the spaces strip (no yabai required).
#
# Everything here is declarative:
#   - modules/darwin/spacebar.nix -> services.spacebar (nix-darwin) -> launchd user agent
#   - colors + icon font resolve from the active theme (lib/themed.nix, themes/*/colors.toml)
#   - omanix.spacebar.* (themes/options.nix) picks items / layout
#
# First launch prompts for Accessibility permission (the plain bar needs AX to read
# the focused window / NSScreens? — clock/power/spaces use native APIs; grant it once
# in System Settings -> Privacy & Security -> Accessibility).
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
  sb = config.omanix.spacebar;

  # Theme color #RRGGBB -> spacebar's "0xffRRGGBB" (ARGB hex, alpha in high byte).
  toSb = hex: "0xff" + (lib.removePrefix "#" hex);

  # Shell-quote a value so keys whose values contain spaces (fonts, clock formats)
  # survive the `spacebar -m config <key> <value>` lines emitted by services.spacebar.
  shq = s: "'" + s + "'";

  spacebarConfig = {
    position          = sb.position;
    display           = sb.display;
    height            = toString sb.height;
    title             = if sb.showTitle then "on" else "off";
    spaces            = if sb.showSpaces then "on" else "off";
    clock             = if sb.showClock then "on" else "off";
    power             = if sb.showPower then "on" else "off";
    dnd               = if sb.showDnd then "on" else "off";
    padding_left      = toString sb.paddingLeft;
    padding_right     = toString sb.paddingRight;
    spacing_left      = toString sb.spacingLeft;
    spacing_right     = toString sb.spacingRight;
    text_font         = shq sb.textFont;
    icon_font         = shq sb.iconFont;
    clock_format      = shq sb.clockFormat;
    background_color  = toSb colors.background;
    foreground_color  = toSb colors.foreground;
    clock_icon_color  = toSb colors.accent;
    power_icon_color  = toSb colors.accent;
    battery_icon_color = toSb colors.foreground;
    dnd_icon_color    = toSb colors.accent;
  };
in {
  # The daemon itself — nix-darwin generates the spacebarrc from `config` and runs it
  # as launchd.user.agents.spacebar (KeepAlive + RunAtLoad). on/off toggles are emitted
  # unconditionally so the rendered script has no constant conditionals (SC2050 rule).
  services.spacebar = {
    enable = sb.enable;
    package = pkgs.spacebar;
    config = spacebarConfig;
  };

  # Install the Font Awesome Free Solid font used by the icon glyphs (clock, power,
  # DND). nixpkgs ships Font Awesome 7.0.1, hence the icon_font "Font Awesome 7 Free".
  fonts.packages = lib.mkIf sb.enable [ pkgs.font-awesome ];

  # Hide the native Control Center status items that a shown bar item replaces, so we
  # don't show clock/battery twice. Built at eval time so no constant conditionals land
  # in the activation script.
  system.activationScripts.postActivation.text = lib.mkAfter (
    (lib.optionalString (sb.enable && sb.showClock) ''
      defaults write com.apple.controlcenter "NSStatusItem Visible Clock" -bool false 2>/dev/null || true
    '') +
    (lib.optionalString (sb.enable && sb.showPower) ''
      defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool false 2>/dev/null || true
    '') +
    (lib.optionalString (sb.enable && (sb.showClock || sb.showPower)) ''
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