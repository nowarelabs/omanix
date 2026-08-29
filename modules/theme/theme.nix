# modules/theme/theme.nix — centralized theme distribution
# Reads themes/<name>/colors.toml -> Nix attrset via lib/themed.nix,
# merges omanix.themeOverrides, and propagates to Ghostty
# See principles.md:3 and docs/themes.md
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
  ghosttyColors = themed.getGhosttyColors config;
  user = config.omanix.user;
  isDark = (colors.mode or "dark") == "dark";
in {
  config = lib.mkIf (user != "") {
    home-manager.users.${user} = {
      xdg.configFile = {
        # Ghostty — terminal colors
        "ghostty/config" = {
          text = themed.ghosttyConfig ghosttyColors;
        };

        # Omanix current theme marker (for Store preview + CLI)
        "omanix/current-theme" = {
          text = config.omanix.theme;
        };

        # Theme JSON for GUI/Store (machine-readable)
        "omanix/theme.json" = {
          text = builtins.toJSON {
            name = config.omanix.theme;
            mode = colors.mode or "dark";
            colors = colors;
            perApp = {
              ghostty = ghosttyColors;
            };
          };
        };
      };

      # Export theme colors as session variables for widgets / apps
      home.sessionVariables = {
        OMANIX_THEME = config.omanix.theme;
        OMANIX_ACCENT = colors.accent;
        OMANIX_BACKGROUND = colors.background;
        OMANIX_FOREGROUND = colors.foreground;
      };
    };

    # macOS appearance — follows theme mode (light/dark)
    system.defaults.NSGlobalDomain.AppleInterfaceStyle = if isDark then "Dark" else null;

    # Write theme.json for runtime consumption (Store, CLI)
    system.activationScripts.postActivation.text = lib.mkAfter ''
      mkdir -p "$HOME/.config/omanix" 2>/dev/null || mkdir -p "/Users/${user}/.config/omanix" 2>/dev/null || true
      cat > "/Users/${user}/.config/omanix/theme.json" <<'THEMEJSON'
      ${builtins.toJSON { name = config.omanix.theme; mode = colors.mode or "dark"; colors = colors; perApp = { ghostty = ghosttyColors; }; }}
      THEMEJSON
      chown ${user}:staff "/Users/${user}/.config/omanix/theme.json" 2>/dev/null || true
    '';
  };
}
