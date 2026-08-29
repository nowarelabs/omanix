# modules/theme/options.nix — theme, bar, and tiling options (the green user surface)
# Extends core omanix.theme enum with per-theme overrides and the native SwiftUI menu bar
# (Omabar) + window-tiling (Omatiles) modules running inside the Omanix app.
# See docs/themes.md and principles.md:3
{ lib, ... }: {
  # --- Omabar: native macOS menu bar replacement (SwiftUI module inside the Omanix app) ---
  options.omanix.omabar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Draw the Omanix menu bar with the native SwiftUI Omabar module (replaces the native macOS menu bar).";
      example = false;
    };

    position = lib.mkOption {
      type = lib.types.enum [ "top" "bottom" ];
      default = "top";
      description = "Menu bar position on screen. Flows around the notch on MacBook Pro.";
      example = "bottom";
    };

    height = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 40;
      description = "Menu bar height in points.";
      example = 48;
    };

    transparent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the menu bar background is fully transparent (no dark tint).";
      example = true;
    };

    blur = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable frosted-glass blur behind the menu bar.";
      example = false;
    };

    style = lib.mkOption {
      type = lib.types.enum [ "default" "glass" "modern" "minimal" ];
      default = "default";
      description = "Omabar visual style. 'glass' forces transparent+blur, 'modern' rounds the workspace pills, 'minimal' drops item backgrounds.";
      example = "glass";
    };

    colorScheme = lib.mkOption {
      type = lib.types.enum [ "auto" "dark" "light" ];
      default = "auto";
      description = "Appearance hint for the bar. 'auto' follows the theme mode (themes/*/colors.toml 'mode' field).";
      example = "dark";
    };

    showClock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the clock on the right side of the bar.";
      example = false;
    };

    showBattery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show battery level on the right side of the bar.";
      example = false;
    };

    showVolume = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show system volume on the right side of the bar.";
      example = false;
    };

    showWifi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the current Wi-Fi network on the right side of the bar.";
      example = false;
    };
  };

  # --- Omatiles: native window tiling manager (SwiftUI/AppKit module inside the Omanix app) ---
  options.omanix.omatiles = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Tile windows with the native Omanix Omatiles engine (Accessibility API). Disable to restore macOS-native window management.";
      example = false;
    };

    layout = lib.mkOption {
      type = lib.types.enum [ "tiles" "columns" "rows" "accordion" ];
      default = "tiles";
      description = "Default layout. Tiles is a strict grid, columns splits vertically, rows stacks horizontally, accordion gives one large pane plus a stack.";
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
      description = "Gap (in px) between tiled windows and the screen edge (increased by the Omabar height on its edge).";
      example = 16;
    };

    bindings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable global Omatiles keyboard bindings (⌘⌥T tile, ⌘⌥J/K focus prev/next, ⌘⌥L cycle layout).";
      example = false;
    };

    watch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Live-tile: re-apply the layout automatically when the set of windows on screen changes.";
      example = true;
    };

    floatingApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "com.apple.finder"
        "com.apple.systempreferences"
        "com.apple.ActivityMonitor"
      ];
      description = "Bundle IDs of apps whose windows are never tiled (dialogs, system panels, overlays).";
      example = [ "com.apple.finder" ];
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
  };
}
