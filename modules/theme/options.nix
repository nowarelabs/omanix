# modules/theme/options.nix — theme, bar, and tiling options (the green user surface)
# Extends core omanix.theme enum with per-theme overrides, the SketchyBar menu bar,
# and the AeroSpace window-tiling manager. All editable from the Store GUI.
# See docs/themes.md and principles.md:3
{ lib, ... }: {
  # --- Menu bar (SketchyBar — macOS menu bar replacement) ---
  options.omanix.bar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Draw the Omanix menu bar with SketchyBar (replaces the native macOS menu bar).";
      example = false;
    };

    position = lib.mkOption {
      type = lib.types.enum [ "top" "bottom" ];
      default = "top";
      description = "Menu bar position on screen. Flows around the notch on MacBook Pro.";
      example = "bottom";
    };

    transparent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the menu bar background is transparent.";
      example = true;
    };

    blur = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable blur behind the menu bar (SketchyBar blur_radius). Requires transparent = true for the glass effect.";
      example = true;
    };

    blurRadius = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 50;
      description = "Blur radius for the menu bar when blur = true (0-100).";
      example = 30;
    };

    style = lib.mkOption {
      type = lib.types.enum [ "default" "minimal" "glass" "modern" ];
      default = "default";
      description = "Menu bar visual style. 'glass' forces transparent+blur, 'minimal' hides separators, 'modern' uses rounded corners.";
      example = "glass";
    };

    height = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 32;
      description = "Menu bar height in points.";
      example = 28;
    };

    colorScheme = lib.mkOption {
      type = lib.types.enum [ "auto" "dark" "light" ];
      default = "auto";
      description = "System appearance hint. 'auto' follows the theme mode (themes/*/colors.toml 'mode' field).";
      example = "dark";
    };
  };

  # --- Window tiling manager (AeroSpace) ---
  options.omanix.tiling = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Tile windows with AeroSpace (i3-like). Disable to restore macOS-native window management.";
      example = false;
    };

    layout = lib.mkOption {
      type = lib.types.enum [ "tiles" "accordion" "floating" ];
      default = "tiles";
      description = "Default layout for new workspaces. Tiles give a strict grid, accordion stacks in a row, floating ignores tiling.";
      example = "accordion";
    };

    gapInner = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 8;
      description = "Gap (in px) between tiled windows.";
      example = 12;
    };

    gapOuter = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 10;
      description = "Gap (in px) between tiled windows and the screen edge.";
      example = 16;
    };

    floatingApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "com.apple.finder"
        "com.apple.systempreferences"
        "com.apple.ActivityMonitor"
      ];
      description = "Bundle IDs that always float instead of tiling (dialogs, system panels, etc.).";
      example = [ "com.apple.finder" ];
    };

    workspaceApps = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "com.google.Chrome" = "B";
        "com.tinyspeck.slackmacgap" = "I";
        "com.hnc.Discord" = "M";
        "md.obsidian" = "N";
        "com.mitchellh.ghostty" = "T";
        "com.apple.Terminal" = "T";
      };
      description = "Bundle ID → workspace-name assignments. New windows are moved to their workspace on launch.";
      example = { "com.tinyspeck.slackmacgap" = "I"; };
    };
  };

  # Per-color overrides — merge on top of themes/<name>/colors.toml
  # User sets e.g. omanix.themeOverrides.accent = "#FF00FF"
  options.omanix.themeOverrides = lib.mkOption {
    type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
    default = {};
    description = "Optional color overrides merged on top of the selected theme palette. Keys are colors.toml vars (accent, background, etc.). Null means use theme default.";
    example = { accent = "#ff00ff"; background = "#0a0a0a"; };
  };

  # Per-application overrides — allow each app to diverge from global palette
  # e.g. omanix.perApp.ghostty.background = "#000000" keeps terminal on pure black
  options.omanix.perApp = {
    ghostty = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {};
      description = "Ghostty-only color overrides (subset of colors.toml keys). Merged on top of global theme+themeOverrides for ghostty/config generation.";
      example = { background = "#000000"; accent = "#ff00ff"; };
    };
    sketchybar = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {};
      description = "SketchyBar-only color overrides. Merged on top of the global theme so the menu bar can diverge from the terminal.";
      example = { background = "#1a1b26"; foreground = "#c0caf5"; };
    };
    aerospace = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.str);
      default = {};
      description = "AeroSpace-only overrides (accent/muted for window borders).";
      example = { accent = "#7aa2f7"; muted = "#414868"; };
    };
  };
}
