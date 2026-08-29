# modules/darwin/desktop.nix — AeroSpace (window tiling) + SketchyBar (menu bar) — Omanix Omakase
# World-class tiling: i3-like via AeroSpace, polished macOS menu bar via SketchyBar, popping borders via JankyBorders.
# Everything is theme-aware (lib/themed.nix) and controlled declaratively from the Store GUI:
#   omanix.tiling.*  (enable, layout, gaps, floating apps, workspace assignments)
#   omanix.bar.*     (enable, position, transparent, blur, style, height, colorScheme)
# References: nikitabobko.github.io/AeroSpace, sketchybar.org, Masstronaut dotfiles
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
  sketchyColors = themed.getSketchyBarColors config;
  aerospaceColors = themed.getAerospaceColors config;
  user = config.omanix.user;

  tiling = config.omanix.tiling;
  bar = config.omanix.bar;

  barIsGlass = bar.style == "glass";
  barTransparent = bar.transparent || barIsGlass;
  barBlur = bar.blur || barIsGlass;
  # Reference-style bar: dark translucent base (0x40-alpha black) so white JetBrainsMono
  # glyphs pop over any wallpaper, with blur on by default. Fully transparent when
  # `omanix.bar.transparent` is set. Theme still drives accent + plugins via colors.sh.
  barColor = if barTransparent then "0x00000000" else "0x40000000";
  barBlurRadius = if barBlur then toString bar.blurRadius else "0";
  barPillCorner = if bar.style == "glass" then "10" else if bar.style == "modern" then "8" else "5";

  # Fonts for the bar. JetBrainsMono Nerd Font (pkgs.nerd-fonts.jetbrains-mono) carries all
  # icons + labels, matching the classic reference config. NOTE: the nixpkgs build registers
  # the family as "JetBrainsMono Nerd Font" (NOT "JetBrainsMono NF") — use that name for
  # CoreText to resolve glyphs. sketchybar-app-font covers per-app icons in front_app.
  # Both fonts are installed system-wide via `fonts.packages` below (CoreText/Font Book),
  # not just a program's extraPackages (which only adds to $PATH, so glyphs render as boxes).
  nerdFont = "JetBrainsMono Nerd Font:Regular:14.0";
  iconFont = "JetBrainsMono Nerd Font:Bold:17.0";
  labelFont = "JetBrainsMono Nerd Font:Bold:14.0";
  appFont = "sketchybar-app-font:Regular:16.0";

  # AeroSpace on-window-detected rules
  floatingRules = map (app: { "if".app-id = app; run = "layout floating"; }) tiling.floatingApps;
  workspaceRules = lib.mapAttrsToList (app: ws: { "if".app-id = app; run = "move-node-to-workspace ${ws}"; }) tiling.workspaceApps;
in {
  # Register the fonts SketchyBar draws glyphs from. Without this, CoreText has
  # nothing to resolve the Nerd Font / app-icon codepoints against, regardless of
  # what `icon.font` is set to in the bar script.
  fonts.packages = with pkgs; [
    sketchybar-app-font
    # nixpkgs restructured nerd-fonts into per-font outputs; if this attr doesn't
    # exist on your pinned nixpkgs, fall back to:
    #   (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    nerd-fonts.jetbrains-mono
  ];

  # --- AeroSpace: window tiling manager ---
  services.aerospace = lib.mkIf tiling.enable {
    enable = true;
    settings = {
      "start-at-login" = false;
      after-startup-command = [
        "exec-and-forget borders active_color=0xff${lib.removePrefix "#" aerospaceColors.accent} inactive_color=0x4000${lib.removePrefix "#" aerospaceColors.muted} width=5.0 style=round || true"
      ] ++ (lib.optionals bar.enable [
        "exec-and-forget sketchybar --reload"
        "exec-and-forget sketchybar"
      ]);
      after-login-command = [];
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      accordion-padding = 30;
      default-root-container-layout = tiling.layout;
      default-root-container-orientation = "auto";
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      automatically-unhide-macos-hidden-apps = false;
      exec-on-workspace-change = [
        "/bin/bash" "-c" "sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE PREV_WORKSPACE=$AEROSPACE_PREV_WORKSPACE"
      ];
      on-window-detected = floatingRules ++ workspaceRules;
      gaps = {
        inner.horizontal = tiling.gapInner;
        inner.vertical = tiling.gapInner;
        outer.left = tiling.gapOuter;
        outer.right = tiling.gapOuter;
        outer.top = if bar.position == "top" then bar.height else tiling.gapOuter;
        outer.bottom = if bar.position == "bottom" then bar.height else tiling.gapOuter;
      };
      key-mapping = { preset = "qwerty"; };
      on-focus-changed = [];
      mode.main.binding = {
        alt-h = "focus left"; alt-j = "focus down"; alt-k = "focus up"; alt-l = "focus right";
        alt-shift-h = "move left"; alt-shift-j = "move down"; alt-shift-k = "move up"; alt-shift-l = "move right";
        alt-minus = "resize smart -50"; alt-equal = "resize smart +50"; alt-shift-minus = "resize smart -50"; alt-shift-equal = "resize smart +50";
        "alt-1" = "workspace 1"; "alt-2" = "workspace 2"; "alt-3" = "workspace 3"; "alt-4" = "workspace 4"; "alt-5" = "workspace 5"; "alt-6" = "workspace 6"; "alt-7" = "workspace 7"; "alt-8" = "workspace 8"; "alt-9" = "workspace 9";
        alt-a = "workspace A"; alt-b = "workspace B"; alt-c = "workspace C"; alt-d = "workspace D"; alt-e = "workspace E"; alt-g = "workspace G"; alt-i = "workspace I"; alt-m = "workspace M"; alt-n = "workspace N"; alt-o = "workspace O"; alt-p = "workspace P"; alt-q = "workspace Q"; alt-r = "workspace R"; alt-s = "workspace S"; alt-t = "workspace T"; alt-u = "workspace U"; alt-v = "workspace V"; alt-w = "workspace W"; alt-x = "workspace X"; alt-y = "workspace Y"; alt-z = "workspace Z";
        "alt-shift-1" = "move-node-to-workspace 1"; "alt-shift-2" = "move-node-to-workspace 2"; "alt-shift-3" = "move-node-to-workspace 3"; "alt-shift-4" = "move-node-to-workspace 4"; "alt-shift-5" = "move-node-to-workspace 5"; "alt-shift-6" = "move-node-to-workspace 6"; "alt-shift-7" = "move-node-to-workspace 7"; "alt-shift-8" = "move-node-to-workspace 8"; "alt-shift-9" = "move-node-to-workspace 9";
        alt-tab = "workspace-back-and-forth"; alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
        alt-f = "fullscreen"; alt-slash = "layout tiles horizontal vertical"; alt-comma = "layout accordion horizontal vertical";
        alt-space = "exec-and-forget open -a 'Omanix'"; alt-shift-semicolon = "mode service"; alt-shift-space = "layout floating tiling";
        cmd-h = []; cmd-alt-h = [];
      };
      mode.service.binding = {
        esc = [ "reload-config" "mode main" ]; r = [ "flatten-workspace-tree" "mode main" ]; f = [ "layout floating tiling" "mode main" ]; backspace = [ "close-all-windows-but-current" "mode main" ];
      };
      mode.resize.binding = {
        h = "resize width -50"; j = "resize height +50"; k = "resize height -50"; l = "resize width +50"; enter = "mode main"; esc = "mode main";
      };
    };
  };

  # --- SketchyBar: macOS menu bar replacement ---
  home-manager.users.${user} = lib.mkIf (user != "" && bar.enable) {
    programs.sketchybar = {
      enable = true;
      configType = "bash";
      extraPackages = with pkgs; [ jq sketchybar-app-font ];
      service.enable = true;
      config = {
        text = ''
          #!/bin/bash
          # Omanix SketchyBar — macOS menu bar replacement, modeled on the classic reference config.
          # Theme: ${config.omanix.theme} | accent ${sketchyColors.accent} | JetBrainsMono Nerd Font
          # Dark translucent bar + blur so white JetBrainsMono NF glyphs pop over any wallpaper.
          # Generated from omanix.bar.* + lib/themed.nix. Fonts from pkgs.nerd-fonts.jetbrains-mono.

          PLUGIN_DIR="$HOME/.config/sketchybar/plugins"

          if [ -f "$HOME/.config/sketchybar/colors.sh" ]; then
            source "$HOME/.config/sketchybar/colors.sh"
          else
            export OMANIX_ACCENT="${sketchyColors.accent}"
            export OMANIX_BACKGROUND="${sketchyColors.background}"
            export OMANIX_FOREGROUND="${sketchyColors.foreground}"
            export OMANIX_MUTED="${sketchyColors.muted}"
            export OMANIX_SELECTION="${sketchyColors.selection}"
            export OMANIX_RED="${colors.red}"
          fi

          to_hex() { echo "0xff''${1#\#}"; }
          ACCENT_HEX=$(to_hex "$OMANIX_ACCENT")

          export NERD_FONT="${nerdFont}"
          export APP_FONT="${appFont}"

          # Bar — ${toString bar.height}px at the ${bar.position} edge, reference look
          sketchybar --bar \
            position="${bar.position}" \
            height=${toString bar.height} \
            blur_radius=${barBlurRadius} \
            color="${barColor}" \
            display=main \
            sticky=on \
            topmost=on

          # Shared defaults: JetBrainsMono NF icons + labels, white on translucent black
          default=(
            padding_left=5
            padding_right=5
            icon.font="${iconFont}"
            label.font="${labelFont}"
            icon.color=0xffffffff
            label.color=0xffffffff
            icon.padding_left=4
            icon.padding_right=4
            label.padding_left=4
            label.padding_right=4
          )
          sketchybar --default "''${default[@]}"

          ${if tiling.enable then ''
          # Workspace pills built from AeroSpace's live workspace list
          sketchybar --add event aerospace_workspace_change
          AEROSPACE_BIN=$(command -v aerospace 2>/dev/null || echo "/opt/homebrew/bin/aerospace")

          for sid in $("$AEROSPACE_BIN" list-workspaces --all 2>/dev/null); do
            sketchybar --add item space.$sid left \
              --subscribe space.$sid aerospace_workspace_change \
              --set space.$sid \
              background.color=0x40ffffff \
              background.corner_radius=${barPillCorner} \
              background.height=25 \
              background.drawing=off \
              icon="$sid" \
              icon.padding_left=7 \
              icon.padding_right=7 \
              label.drawing=off \
              click_script="$AEROSPACE_BIN workspace $sid" \
              script="$PLUGIN_DIR/aerospace.sh $sid"
          done
          '' else ''
          # No AeroSpace: static workspace pills 1-9
          SPACE_ICONS=("1" "2" "3" "4" "5" "6" "7" "8" "9")
          for i in "''${!SPACE_ICONS[@]}"; do
            sid="$(($i+1))"
            sketchybar --add item space.$sid left \
              --set space.$sid \
              background.color=0x40ffffff \
              background.corner_radius=${barPillCorner} \
              background.height=25 \
              background.drawing=off \
              icon="''${SPACE_ICONS[i]}" \
              icon.padding_left=7 \
              icon.padding_right=7 \
              label.drawing=off
          done
          ''}

          ##### Adding Left Items #####
          # Apple → Omanix launcher, then chevron + front app
          sketchybar --add item omanix.apple left \
            --set omanix.apple icon="🍎" icon.color="$ACCENT_HEX" label.drawing=off \
            --add item chevron left \
            --set chevron icon="" label.drawing=off \
            --add item front_app left \
            --set front_app icon.drawing=off script="$PLUGIN_DIR/front_app.sh" \
            --subscribe front_app front_app_switched

          ##### Adding Right Items #####
          # Clock ticks every 10s; volume + battery react to system events
          sketchybar --add item clock right \
            --set clock update_freq=10 icon="" script="$PLUGIN_DIR/clock.sh" \
            --add item volume right \
            --set volume script="$PLUGIN_DIR/volume.sh" \
            --subscribe volume volume_change \
            --add item battery right \
            --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh" \
            --subscribe battery system_woke power_source_change \
            --add item wifi right \
            --set wifi icon="" label.drawing=off script="$PLUGIN_DIR/wifi.sh" \
            --add item omanix.notification right \
            --set omanix.notification icon="" icon.color="0xff${lib.removePrefix "#" colors.red}" label.drawing=off drawing=off

          sketchybar --default popup.background.color=0xcc262626 popup.background.border_color=0xff555555 popup.background.corner_radius=10 popup.blur_radius=${barBlurRadius}

          # Omanix widgets — nix → sketchybar --trigger event system (lib/mkWidget / lib/mkBarItem)
          for plugin in "$HOME/.config/sketchybar/plugins/"omanix-*.sh "$HOME/.config/sketchybar/plugins/"pomodoro.sh "$HOME/.config/sketchybar/plugins/"clock.sh; do
            [ -x "$plugin" ] && [ -f "$plugin" ] && source "$plugin" 2>/dev/null || true
          done

          sketchybar --update
        '';
      };
    };

    xdg.configFile."sketchybar/plugins/aerospace.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        # Omanix aerospace workspace pill highlight — focused = theme accent, rest = translucent white
        if [ -f "$HOME/.config/sketchybar/colors.sh" ]; then source "$HOME/.config/sketchybar/colors.sh"; fi
        to_hex() { echo "0xff''${1#\#}"; }
        ACCENT_HEX=$(to_hex "''${OMANIX_ACCENT:-#0A7CFF}")
        if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
          sketchybar --set $NAME background.drawing=on background.color="$ACCENT_HEX" icon.color=0xffffffff icon.font="''${NERD_FONT:-JetBrainsMono Nerd Font:Regular:14.0}"
        else
          if [ "$1" = "$TARGET_WORKSPACE" ] && [ -n "$TARGET_WORKSPACE" ]; then
            sketchybar --set $NAME background.drawing=on background.color=0x80ffffff icon.color=0xffffffff
          else
            sketchybar --set $NAME background.drawing=on background.color=0x40ffffff icon.color=0xffffffff icon.font="''${NERD_FONT:-JetBrainsMono Nerd Font:Regular:14.0}"
          fi
        fi
      '';
    };

    xdg.configFile."sketchybar/plugins/front_app.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        # Front app — shows focused app's icon (sketchybar-app-font) + name label
        if [ "$SENDER" = "front_app_switched" ]; then
          sketchybar --set $NAME label="$INFO"
          ICON=""
          if command -v icon_map.sh >/dev/null 2>&1; then
            ICON=$(icon_map.sh "$INFO" 2>/dev/null)
          fi
          if [ -n "$ICON" ]; then
            sketchybar --set $NAME icon="$ICON" icon.font="''${APP_FONT:-sketchybar-app-font:Regular:16.0}"
          else
            # No app-specific glyph mapped: fall back to an emoji, which always
            # renders regardless of which Nerd Font build is installed.
            sketchybar --set $NAME icon="🖥️"
          fi
        fi
      '';
    };

    xdg.configFile."sketchybar/plugins/clock.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        sketchybar --set $NAME label="$(date '+%a %d %b %H:%M')" icon="" icon.font="''${NERD_FONT:-JetBrainsMono Nerd Font:Regular:14.0}"
      '';
    };

    xdg.configFile."sketchybar/plugins/battery.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        PERCENT=$(pmset -g batt 2>/dev/null | grep -Eo "[0-9]+%" | cut -d% -f1)
        if [ -z "$PERCENT" ]; then sketchybar --set $NAME drawing=off; exit 0; fi
        if [ "$PERCENT" -gt 80 ]; then ICON="󰁹"; elif [ "$PERCENT" -gt 50 ]; then ICON="󰁿"; elif [ "$PERCENT" -gt 20 ]; then ICON="󰁾"; else ICON="󰁺"; fi
        sketchybar --set $NAME icon="$ICON" icon.font="''${NERD_FONT:-JetBrainsMono Nerd Font:Regular:14.0}" label="''${PERCENT}%" drawing=on
      '';
    };

    xdg.configFile."sketchybar/plugins/volume.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        VOL=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || echo 50)
        if [ "$VOL" = "0" ] || [ "$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)" = "true" ]; then ICON=""; else ICON=""; fi
        sketchybar --set $NAME icon="$ICON" icon.font="''${NERD_FONT:-JetBrainsMono Nerd Font:Regular:14.0}" label="''${VOL}%"
      '';
    };

    xdg.configFile."sketchybar/plugins/wifi.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        WIFI=$(networksetup -getairportnetwork en0 2>/dev/null | sed 's/You are not associated.*//')
        if [ -n "$WIFI" ]; then ICON="📶"; else ICON="🚫"; fi
        sketchybar --set $NAME icon="$ICON" label.drawing=off
      '';
    };
  };

  # Goodies: hide the native Mac menu bar so SketchyBar is the only bar, remove window launcher friction,
  # and one-click Accessibility grant for AeroSpace. Built conditionally at eval time so the
  # generated activation script has no constant conditionals (shellcheck SC2050 → build failure).
  system.activationScripts.postActivation.text = lib.mkAfter (
    (lib.optionalString bar.enable ''
      # Hide native Mac menu bar so Omanix's SketchyBar is the only bar (no competition)
      defaults write NSGlobalDomain _HIHideMenuBar -bool true 2>/dev/null || true
      defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false 2>/dev/null || true
      defaults write -g NSWindowShouldDragOnGesture -bool true 2>/dev/null || true
      defaults write com.apple.spaces spans-displays -bool true 2>/dev/null || true
      killall ControlCenter 2>/dev/null || true
    '') +
    # Disable competing swipe/sidebar navigation regardless of tiling state
    ''
      defaults write -g AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
      defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
      defaults write com.apple.dock expose-group-by-app -bool false 2>/dev/null || true
      killall SystemUIServer 2>/dev/null || true
      killall Dock 2>/dev/null || true
    '' +
    (lib.optionalString tiling.enable ''
      # AeroSpace Accessibility: one-click grant when tiling is enabled
      AEROSPACE_BIN=$(command -v aerospace 2>/dev/null || echo "/opt/homebrew/bin/aerospace")
      if [ -x "$AEROSPACE_BIN" ]; then
        if ! "$AEROSPACE_BIN" list-workspaces --all >/dev/null 2>&1; then
          echo ""
          echo "┌─────────────────────────────────────────────────────────┐"
          echo "│  Omanix: Grant Accessibility to AeroSpace (one click)  │"
          echo "│  Click 'Open Settings' → + → add AeroSpace → Done     │"
          echo "└─────────────────────────────────────────────────────────┘"
          if command -v osascript >/dev/null 2>&1; then
            osascript -e 'display dialog "Omanix needs Accessibility for AeroSpace to tile windows.\n\nClick Open Settings → + → add AeroSpace." buttons {"Open Settings", "Later"} default button "Open Settings" with title "Omanix — AeroSpace"' 2>/dev/null | grep -q "Open Settings" && \
            open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
          else
            open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
          fi
          echo "Tip: re-run 'omanix rebuild' after granting"
        else
          echo "AeroSpace Accessibility: OK"
        fi
      fi
    '')
  );
}
