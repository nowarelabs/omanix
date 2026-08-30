# modules/theme/options.nix — theme, bar, and tiling options (the green user surface)
# Extends core omanix.theme enum with per-theme overrides and the native-macOS
# Omabar (status items in Apple's menu bar) + Omatiles (bridge onto macOS's own
# Sequoia window tiling). Both build on the OS instead of replacing it.
# See docs/themes.md and principles.md:3
{ lib, ... }: {
  # --- Omabar: Omanix items INSIDE the native macOS menu bar (status items) ---
  options.omanix.omabar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the Omabar status items (clock, battery, volume, Wi-Fi, running apps) into the native macOS menu bar.";
      example = false;
    };

    showClock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the clock as a menu bar status item (click opens Calendar).";
      example = false;
    };

    showBattery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show battery level as a menu bar status item.";
      example = false;
    };

    showVolume = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show system volume as a menu bar status item.";
      example = false;
    };

    showVolumeText = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Render the numeric volume percentage beside the speaker icon. When false, only the icon is shown.";
      example = false;
    };

    showWifi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the current Wi-Fi network as a menu bar status item.";
      example = false;
    };

    showApps = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show the frontmost app in the menu bar, with a menu of all on-screen apps to switch to.";
      example = true;
    };

    # --- Omabar clock / battery display preferences (Nix-owned; GUI writes via
    # `omanix state set` and applies live — mirrors the macOS-only live path) ---
    autoHide = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Hide the macOS menu bar until the pointer reaches the top of the screen.";
      example = true;
    };

    showDate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Render the abbreviated date beside the time in the clock status item.";
      example = false;
    };

    showBatteryPercent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the numeric charge percentage beside the battery icon.";
      example = false;
    };

    use24Hour = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use a 24-hour clock instead of 12-hour.";
      example = true;
    };

    clockFormat = lib.mkOption {
      type = lib.types.enum [ "digital" "analog" ];
      default = "digital";
      description = "How the clock is drawn: 'digital' (HH:mm text) or 'analog' (small clock glyph).";
      example = "analog";
    };

    # --- Structured declarative components (Phase 3: Module-Based Configuration) ---
    # The canonical, Nix-owned surface for bar layout. When set, `components.<name>.enable`
    # overrides the flat `show*` toggles above; this makes the entire desktop layout a
    # strongly-typed compilation input, as the brief's declarative & state-compiled model
    # requires. Supported built-ins: clock, battery, volume, wifi, apps. Custom keys
    # become compile-time plugins in Phase 5.
    components = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Show this component in the Omabar.";
          example = false;
        };
        options.showText = lib.mkOption {
          type = lib.types.nullOr lib.types.bool;
          default = null;
          description = "Show text beside the icon when applicable (battery %, volume %). Null defers to the component's default.";
          example = false;
        };
        options.style = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Visual style variant, e.g. \"digital\" / \"analog\" for clock.";
          example = "analog";
        };
        options.colorScheme = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional color-scheme override for this component (merged with the global theme).";
          example = "dracula";
        };
      });
      default = {};
      description = "Declarative per-component configuration for the Omabar. Keys are component IDs (clock, battery, volume, wifi, apps, ...). When present, `components.<name>.enable` overrides the flat `show*` toggle.";
      example = {
        clock = { enable = true; style = "digital"; };
        battery = { enable = true; showText = false; };
        volume = { enable = true; showText = true; };
      };
    };
  };

  # --- Omatiles: a thin bridge onto macOS Sequoia's BUILT-IN window tiling ---
  # No layout engine, no AX window moving: tiling itself is the OS's own feature
  # (drag-to-edge, ⌃⌥+arrow keyboard tiling). Omatiles just flips the System
  # Settings "Window management" switches declaratively (darwin/omatiles.nix) and
  # re-binds our own ⌘⌥+arrow keys to the platform's tiling shortcuts.
  options.omanix.omatiles = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Omatiles module (registers the global ⌘⌥ tiling bindings when bindings is true).";
      example = false;
    };

    bindings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Global bindings (⌘⌥←/→/↑/↓ half-tile, ⌘⌥Z untile) that invoke macOS's own ⌃⌥+arrow tiling.";
      example = false;
    };

    enableEdgeDrag = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "macOS Sequoia: drag a window to a screen edge to tile it.";
      example = false;
    };

    enableKeyboardShortcuts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "macOS Sequoia: enable the system ⌃⌥+arrow tiling keyboard shortcuts.";
      example = false;
    };

    enableMargins = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "macOS Sequoia: keep a margin between tiled windows.";
      example = true;
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

  # --- Owin: declarative window manager (Phase 4: deterministic workspace mappings) ---
  # The brief's "Anti-AeroSpace" — a Declarative Layout Engine that routes windows
  # via a Nix-generated static map and AXUI hooks, not a standalone daemon's
  # imperative tree. Enabling requires Accessibility permission; layouts are
  # type-safe functions (bsp/monocle/stack/spiral) on a per-workspace basis.
  options.omanix.owin = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the native Owin window manager (AXUI-based, declarative). When false, Omatiles (macOS built-in tiling bridge) remains the tiling surface.";
      example = true;
    };
    defaultLayout = lib.mkOption {
      type = lib.types.enum [ "bsp" "monocle" "stack" "spiral" "float" ];
      default = "bsp";
      description = "Fallback layout for workspaces not explicitly configured or for floating windows.";
      example = "monocle";
    };
  };

  options.omanix.workspaces = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options.monitor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Monitor to pin this workspace to (e.g. \"Built-in Display\" or \"External 4K\" via NSScreen.localizedName). Null means follow the focused screen.";
        example = "External 4K";
      };
      options.layout = lib.mkOption {
        type = lib.types.enum [ "bsp" "monocle" "stack" "spiral" "float" ];
        default = "bsp";
        description = "Layout algorithm for this workspace.";
        example = "monocle";
      };
      options.apps = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Bundle IDs or app names to auto-route to this workspace on launch. Evaluated against the app's CFBundleIdentifier at launch via AXUI.";
        example = [ "com.brave.Browser" "Ghostty" ];
      };
    });
    default = {};
    description = "Deterministic workspace mappings. Each key is a workspace name like \"1: Web\" or \"2: Code\"; Owin uses the Nix-generated static map to route windows on launch without a daemon. See modules/apps/gui/Modules/Omatiles/WorkspaceManager.swift.";
    example = {
      "1: Web" = { monitor = "External 4K"; layout = "monocle"; apps = [ "Brave" "Slack" ]; };
      "2: Code" = { monitor = "Built-in Display"; layout = "bsp"; apps = [ "Ghostty" ]; };
    };
  };
}
