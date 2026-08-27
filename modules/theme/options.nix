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
}
