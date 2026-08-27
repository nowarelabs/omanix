# modules/theme/theme.nix — centralized theme distribution (Omarchy parity)
# Reads themes/<name>/colors.toml -> Nix attrset via lib/themed.nix,
# merges omanix.themeOverrides, and propagates to Ghostty, SketchyBar, AeroSpace
# See principles.md:3 and docs/themes.md
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
  ghosttyColors = themed.getGhosttyColors config;
  sketchyColors = themed.getSketchyBarColors config;
  aerospaceColors = themed.getAerospaceColors config;
  user = config.omanix.user;
  isDark = (colors.mode or "dark") == "dark" || config.omanix.bar.colorScheme == "dark" || (config.omanix.bar.colorScheme == "auto" && (colors.mode or "dark") == "dark");
  # Resolve bar appearance — glass forces transparent+blur
  barIsGlass = config.omanix.bar.style == "glass";
  barTransparent = config.omanix.bar.transparent || barIsGlass;
  barBlur = config.omanix.bar.blur || barIsGlass;
  barBg = if barTransparent then "0x00000000" else sketchyColors.background;
  # Transition lives at omanix.transition (theme is a string enum, cannot nest). Fallback to theme.transition for spec alias.
  transitionEnable =
    if config ? omanix && config.omanix ? transition && config.omanix.transition ? enable
    then config.omanix.transition.enable
    else if config ? omanix && config.omanix ? theme && builtins.isAttrs config.omanix.theme && config.omanix.theme ? transition && config.omanix.theme.transition ? enable
    then config.omanix.theme.transition.enable else true;
  transitionDuration =
    if config ? omanix && config.omanix ? transition && config.omanix.transition ? duration
    then config.omanix.transition.duration
    else if config ? omanix && config.omanix ? theme && builtins.isAttrs config.omanix.theme && config.omanix.theme ? transition && config.omanix.theme.transition ? duration
    then config.omanix.theme.transition.duration else 200;
  transitionType =
    if config ? omanix && config.omanix ? transition && config.omanix.transition ? type
    then config.omanix.transition.type
    else if config ? omanix && config.omanix ? theme && builtins.isAttrs config.omanix.theme && config.omanix.theme ? transition && config.omanix.theme.transition ? type
    then config.omanix.theme.transition.type else "crossfade";
  # SketchyBar animate frames: duration ms -> frames approx duration/15
  animateFrames = toString (if transitionDuration < 30 then 2 else transitionDuration / 15);
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
        # Uses per-app overrides: omanix.theme.perApp.ghostty.*
        "ghostty/config" = {
          text = themed.ghosttyConfig ghosttyColors;
        };

        # SketchyBar color variables — sourced by sketchybarrc
        # Provides OMANIX_* env vars for bar plugins — uses sketchybar per-app overrides
        "sketchybar/colors.sh" = {
          text = themed.sketchyBarColors sketchyColors barTransparent;
          executable = true;
        };

        # Theme transition helper — called by activation and by `omanix theme` CLI
        "omanix/theme-transition.sh" = {
          text = ''
            #!/bin/bash
            # Omanix theme transition — generated via modules/theme/theme.nix
            # Type: ${transitionType}, duration: ${toString transitionDuration}ms, enable: ${if transitionEnable then "true" else "false"}
            set -e
            if [ "${if transitionEnable then "1" else "0"}" = "0" ]; then
              sketchybar --reload 2>/dev/null || true
              exit 0
            fi
            case "${transitionType}" in
              crossfade)
                # Fade bar out -> reload -> fade in via animate
                if pgrep -x sketchybar >/dev/null 2>&1; then
                  sketchybar --animate sin ${animateFrames} --bar color=0x00000000 2>/dev/null || true
                  sleep $(awk "BEGIN {print ${toString transitionDuration}/1000/2}")
                  sketchybar --reload 2>/dev/null || true
                  sketchybar --animate sin ${animateFrames} --bar color=${barBg} 2>/dev/null || true
                else
                  sketchybar --reload 2>/dev/null || true
                fi
                ;;
              slide)
                if pgrep -x sketchybar >/dev/null 2>&1; then
                  sketchybar --animate sin ${animateFrames} --bar y_offset=-32 2>/dev/null || true
                  sleep $(awk "BEGIN {print ${toString transitionDuration}/1000/2}")
                  sketchybar --reload 2>/dev/null || true
                  sketchybar --animate sin ${animateFrames} --bar y_offset=0 2>/dev/null || true
                else
                  sketchybar --reload 2>/dev/null || true
                fi
                ;;
              *)
                sketchybar --reload 2>/dev/null || true
                ;;
            esac
          '';
          executable = true;
        };

        # Omanix current theme marker (for Store preview + CLI)
        "omanix/current-theme" = {
          text = config.omanix.theme;
        };

        # Theme JSON for GUI/Store (machine-readable) — includes per-app deltas
        "omanix/theme.json" = {
          text = builtins.toJSON ({
            name = config.omanix.theme;
            mode = colors.mode or "dark";
            colors = colors;
            perApp = {
              ghostty = ghosttyColors;
              sketchybar = sketchyColors;
              aerospace = aerospaceColors;
            };
            bar = {
              position = config.omanix.bar.position;
              transparent = barTransparent;
              blur = barBlur;
              blurRadius = config.omanix.bar.blurRadius;
              style = config.omanix.bar.style;
              colorScheme = config.omanix.bar.colorScheme;
              background = barBg;
            };
            transition = {
              enable = transitionEnable;
              duration = transitionDuration;
              type = transitionType;
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

    # macOS appearance — follows theme mode + bar.colorScheme (makes theme switch obvious: light vs dark)
    # Omanix light (#FBFBFC) -> Light, all dark themes -> Dark. Also respected via Store/GUI.
    system.defaults.NSGlobalDomain.AppleInterfaceStyle = if isDark then "Dark" else null;

    # Also write a store file for AeroSpace border colors (consumed by desktop.nix activation)
    # We create /tmp/omanix-theme for runtime reload
    system.activationScripts.postActivation.text = lib.mkAfter ''
      mkdir -p "$HOME/.config/omanix" 2>/dev/null || mkdir -p "/Users/${user}/.config/omanix" 2>/dev/null || true
      cat > "/Users/${user}/.config/omanix/theme.json" <<'THEMEJSON'
      ${builtins.toJSON { name = config.omanix.theme; colors = colors; perApp = { ghostty = ghosttyColors; sketchybar = sketchyColors; aerospace = aerospaceColors; }; bar = { transparent = barTransparent; blur = barBlur; blurRadius = config.omanix.bar.blurRadius; style = config.omanix.bar.style; background = sketchyColors.background; foreground = sketchyColors.foreground; accent = sketchyColors.accent; selection = sketchyColors.selection; muted = sketchyColors.muted; }; transition = { enable = transitionEnable; duration = transitionDuration; type = transitionType; }; }}
      THEMEJSON
      chown ${user}:staff "/Users/${user}/.config/omanix/theme.json" 2>/dev/null || true
      chmod +x "/Users/${user}/.config/omanix/theme-transition.sh" 2>/dev/null || true
      # Theme transition: animate if enabled, else instant reload
      if [ -x "/Users/${user}/.config/omanix/theme-transition.sh" ]; then
        "/Users/${user}/.config/omanix/theme-transition.sh" 2>/dev/null || sketchybar --reload 2>/dev/null || true
      elif pgrep -x sketchybar >/dev/null 2>&1; then
        sketchybar --reload 2>/dev/null || true
      fi
    '';
  };
}
