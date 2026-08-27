# modules/theme/theme.nix — centralized theme distribution (Omarchy parity)
# Reads themes/<name>/colors.toml -> Nix attrset via lib/themed.nix,
# merges omanix.themeOverrides, and propagates to Ghostty, SketchyBar, AeroSpace
# See principles.md:3 and docs/themes.md
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
  user = config.omanix.user;
  isDark = (colors.mode or "dark") == "dark" || config.omanix.bar.colorScheme == "dark" || (config.omanix.bar.colorScheme == "auto" && (colors.mode or "dark") == "dark");
  # Resolve bar appearance — glass forces transparent+blur
  barIsGlass = config.omanix.bar.style == "glass";
  barTransparent = config.omanix.bar.transparent || barIsGlass;
  barBlur = config.omanix.bar.blur || barIsGlass;
  barBg = if barTransparent then "0x00000000" else colors.background;
in {
  # Expose merged colors for other modules via config.lib.omanixTheme if needed
  # (other modules import themed.nix directly, but this is the propagated source)

  # Host-side: write themed configs to user's XDG
  # Only configure home-manager if user is set (assertions guarantee it)
  config = lib.mkIf (user != "") {
    # Cross-application theme propagation
    home-manager.users.${user} = {
      xdg.configFile = {
        # Ghostty — terminal colors (Omarchy parity: ~/.local/state/omarchy/current/theme/ghostty.conf)
        "ghostty/config" = {
          text = themed.ghosttyConfig colors;
        };

        # SketchyBar color variables — sourced by sketchybarrc
        # Provides OMANIX_* env vars for bar plugins
        "sketchybar/colors.sh" = {
          text = themed.sketchyBarColors colors barTransparent;
          executable = true;
        };

        # Omanix current theme marker (for Store preview + CLI)
        "omanix/current-theme" = {
          text = config.omanix.theme;
        };

        # Theme JSON for GUI/Store (machine-readable)
        "omanix/theme.json" = {
          text = builtins.toJSON ({
            name = config.omanix.theme;
            mode = colors.mode or "dark";
            colors = colors;
            bar = {
              position = config.omanix.bar.position;
              transparent = barTransparent;
              blur = barBlur;
              blurRadius = config.omanix.bar.blurRadius;
              style = config.omanix.bar.style;
              colorScheme = config.omanix.bar.colorScheme;
              background = barBg;
            };
          });
        };
      };

      # Export theme colors as session variables for widgets / apps (lib/mkWidget reads them)
      home.sessionVariables = {
        OMANIX_THEME = config.omanix.theme;
        OMANIX_ACCENT = colors.accent;
        OMANIX_BACKGROUND = colors.background;
        OMANIX_FOREGROUND = colors.foreground;
      };
    };

    # macOS appearance — set dark/light based on theme mode + bar.colorScheme
    # NSGlobalDomain AppleInterfaceStyle = "Dark" for dark, absent for light
    system.defaults.NSGlobalDomain = lib.mkIf (config.omanix.bar.colorScheme != "auto") {
      AppleInterfaceStyle = if config.omanix.bar.colorScheme == "dark" then "Dark" else null;
    };

    # Also write a store file for AeroSpace border colors (consumed by desktop.nix activation)
    # We create /tmp/omanix-theme for runtime reload
    system.activationScripts.postActivation.text = lib.mkAfter ''
      mkdir -p "$HOME/.config/omanix" 2>/dev/null || mkdir -p "/Users/${user}/.config/omanix" 2>/dev/null || true
      cat > "/Users/${user}/.config/omanix/theme.json" <<'THEMEJSON'
      ${builtins.toJSON { name = config.omanix.theme; colors = colors; bar = { transparent = barTransparent; blur = barBlur; blurRadius = config.omanix.bar.blurRadius; style = config.omanix.bar.style; background = colors.background; foreground = colors.foreground; accent = colors.accent; selection = colors.selection; muted = colors.muted; }; }}
      THEMEJSON
      chown ${user}:staff "/Users/${user}/.config/omanix/theme.json" 2>/dev/null || true
      # Reload SketchyBar if running
      if pgrep -x sketchybar >/dev/null 2>&1; then
        sketchybar --reload 2>/dev/null || true
      fi
    '';
  };
}
