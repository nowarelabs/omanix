# modules/theme/options.nix — theme, bar, and tiling options (the green user surface)
# Extends core omanix.theme enum with per-theme overrides, the external Spacebar
# (full-width status bar drawn by the spacebar daemon, github.com/cmacrae/spacebar),
# and Omatiles (bridge onto macOS's own Sequoia window tiling). Both build on the OS
# instead of replacing it — no yabai, no sketchybar.
# See docs/themes.md and principles.md:3
{ lib, ... }: {
  # --- Spacebar: full-width status bar OUTSIDE the native macOS menu bar ---
  # The external `spacebar` daemon (github.com/cmacrae/spacebar) draws its own bar
  # just below the native menu bar (position "top") or at the screen bottom, replacing
  # the old in-menu-bar Omabar status items. It is fully configured from Nix via
  # modules/darwin/spacebar.nix, which resolves colors + the Font Awesome icon font
  # from the active theme. The options below only pick which items are shown and how
  # the bar is laid out. Standalone — works without yabai (the spaces strip shows the
  # native Mission Control count when enabled).
  options.omanix.spacebar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the spacebar daemon (runs as a launchd user agent at login).";
      example = false;
    };

    position = lib.mkOption {
      type = lib.types.enum [ "top" "bottom" ];
      default = "top";
      description = "Bar placement: 'top' draws it just below the native menu bar, 'bottom' at the bottom of the screen.";
      example = "bottom";
    };

    display = lib.mkOption {
      type = lib.types.enum [ "all" "main" ];
      default = "all";
      description = "Which displays the bar appears on: 'all' (every display) or 'main' (the primary display only).";
      example = "main";
    };

    height = lib.mkOption {
      type = lib.types.int;
      default = 26;
      description = "Bar height in points.";
      example = 32;
    };

    showClock = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the clock, formatted per clockFormat.";
      example = false;
    };

    clockFormat = lib.mkOption {
      type = lib.types.str;
      default = "%R";
      description = "strftime format for the clock. '%R' is 24-hour HH:MM; '%I:%M %p' is 12-hour with AM/PM.";
      example = "%I:%M %p";
    };

    showPower = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show the power indicator (battery charge + charging bolt).";
      example = false;
    };

    showTitle = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show the title of the focused window in the bar.";
      example = true;
    };

    showSpaces = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show the Mission Control spaces strip (numbered spaces; no yabai symbols). Off by default — Omatiles drives window management here.";
      example = true;
    };

    showDnd = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show the Do Not Disturb toggle (click toggles DND).";
      example = true;
    };

    paddingLeft = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Left padding inside the bar, in points.";
      example = 12;
    };

    paddingRight = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Right padding inside the bar, in points.";
      example = 12;
    };

    spacingLeft = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Space before the first item, in points.";
      example = 10;
    };

    spacingRight = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "Space between items, in points.";
      example = 10;
    };

    textFont = lib.mkOption {
      type = lib.types.str;
      default = "Helvetica Neue:Regular:12.0";
      description = "CoreText font for bar text: '<PostScript name>:<weight>:<point size>'.";
      example = "SF Pro Text:Medium:13.0";
    };

    iconFont = lib.mkOption {
      type = lib.types.str;
      default = "Font Awesome 7 Free:Solid:12.0";
      description = "CoreText font for bar icons. Defaults to the Font Awesome Free Solid family shipped via pkgs.font-awesome (Font Awesome 7) in modules/darwin/spacebar.nix.";
      example = "Font Awesome 6 Free:Solid:12.0";
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
