# modules/theme/options.nix — theme + bar options (the green user surface)
# Extends core omanix.theme enum with per-theme overrides and bar styling
# See docs/themes.md and principles.md:3
{ lib, ... }: {
  options.omanix.bar = {
    position = lib.mkOption {
      type = lib.types.enum [ "top" "bottom" ];
      default = "top";
      description = "Bar position on screen. Flows around the notch on MacBook Pro.";
      example = "bottom";
    };

    transparent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the bar background is transparent.";
      example = true;
    };

    blur = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable blur behind the bar (SketchyBar blur_radius). Requires transparent = true for glass effect.";
      example = true;
    };

    blurRadius = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 50;
      description = "Blur radius for the bar when blur = true (0-100).";
      example = 30;
    };

    style = lib.mkOption {
      type = lib.types.enum [ "default" "minimal" "glass" "modern" ];
      default = "default";
      description = "Bar visual style. 'glass' forces transparent+blur, 'minimal' hides separators, 'modern' uses rounded corners.";
      example = "glass";
    };

    colorScheme = lib.mkOption {
      type = lib.types.enum [ "auto" "dark" "light" ];
      default = "auto";
      description = "System appearance hint. 'auto' follows theme mode (themes/*/colors.toml mode field).";
      example = "dark";
    };
  };

  # Per-color overrides — merge on top of themes/<name>/colors.toml
  # User sets e.g. omanix.themeOverrides.accent = "#FF00FF"
  # (alias omanix.theme.colors.* is supported at eval via lib/themed.nix for back-compat spec)
  options.omanix.themeOverrides = lib.mkOption {
    type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
    default = {};
    description = "Optional color overrides merged on top of the selected theme palette. Keys are colors.toml vars (accent, background, etc.). Null means use theme default. Equivalent to spec's omanix.theme.colors.custom.";
    example = { accent = "#ff00ff"; background = "#0a0a0a"; };
  };

  # Per-application overrides — allow each app to diverge from global palette
  # Nix forbids nesting under omanix.theme (it is a string enum), so we expose as omanix.perApp.
  # Spec alias omanix.theme.perApp.* is not a real option; use omanix.perApp.* (same effect).
  # e.g. omanix.perApp.ghostty.background = "#000000" keeps bar on tokyo-night but terminal on pure black
  options.omanix.perApp = {
    ghostty = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {};
      description = "Ghostty-only color overrides (subset of colors.toml keys). Merged on top of global theme+themeOverrides for ghostty/config generation. CLI: omanix theme per-app ghostty background \"#000000\"";
      example = { background = "#000000"; accent = "#ff00ff"; };
    };
    sketchybar = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {};
      description = "SketchyBar-only color overrides. Merged on top of global theme for bar colors.sh and sketchybarrc. Use to keep bar readable when terminal uses a different bg.";
      example = { background = "#1a1b26"; foreground = "#c0caf5"; };
    };
    aerospace = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {};
      description = "AeroSpace-only overrides (accent/muted for window borders).";
      example = { accent = "#7aa2f7"; muted = "#414868"; };
    };
  };

  # Transition animation when theme changes (SketchyBar --animate, Ghostty restart fade)
  # Also exposed as omanix.transition because omanix.theme is a string enum (cannot nest)
  options.omanix.transition = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Animate theme switches (SketchyBar --animate sin 15). Disable for instant cut. Spec alias: omanix.theme.transition.enable";
      example = false;
    };
    duration = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 200;
      description = "Animation duration in ms (0-1000) when transition.enable = true.";
      example = 400;
    };
    type = lib.mkOption {
      type = lib.types.enum [ "crossfade" "slide" "none" ];
      default = "crossfade";
      description = "Transition style: crossfade (opacity), slide (bar y_offset), or none.";
      example = "crossfade";
    };
  };
}
