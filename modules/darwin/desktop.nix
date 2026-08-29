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
  barCornerRadius = if bar.style == "glass" then "10" else if bar.style == "modern" then "8" else "0";
  barBorderWidth = if bar.style == "minimal" then "0" else "1";
  barColor = if barTransparent then "0x00000000" else "0xff${lib.removePrefix "#" sketchyColors.background}";
  barBorderColor = "0xff${lib.removePrefix "#" sketchyColors.muted}";
  barBlurRadius = if barBlur then toString bar.blurRadius else "0";

  gapOuterTop = if bar.position == "top" then bar.height else tiling.gapOuter;
  gapOuterBottom = if bar.position == "bottom" then bar.height else tiling.gapOuter;

  # Workspace pills shown in the bar: numeric 1-9 + every workspace named in omanix.tiling.workspaceApps
  spaces = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" ] ++ lib.unique (lib.attrValues tiling.workspaceApps);

  # AeroSpace on-window-detected rules
  floatingRules = map (app: { "if".app-id = app; run = "layout floating"; }) tiling.floatingApps;
  workspaceRules = lib.mapAttrsToList (app: ws: { "if".app-id = app; run = "move-node-to-workspace ${ws}"; }) tiling.workspaceApps;
in {
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
        outer.top = gapOuterTop;
        outer.bottom = gapOuterBottom;
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
          # Omanix SketchyBar — macOS menu bar replacement, generated from omanix.bar + lib/themed.nix
          # Theme: ${config.omanix.theme} | ${sketchyColors.background} -> ${sketchyColors.foreground} | accent ${sketchyColors.accent}
          # Matches the GUI app palette: page #FBFBFC, card white, border #E6E6EA, text #1D1D1F

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
          BG_HEX=$(to_hex "$OMANIX_BACKGROUND")
          FG_HEX=$(to_hex "$OMANIX_FOREGROUND")
          MUTED_HEX=$(to_hex "$OMANIX_MUTED")
          SELECTION_HEX=$(to_hex "$OMANIX_SELECTION")

          # Bar — menu-bar replacement, ${toString bar.height}px at ${bar.position} edge
          sketchybar --bar \
            position="${bar.position}" \
            height=${toString bar.height} \
            color="${barColor}" \
            border_width=${barBorderWidth} \
            border_color="${barBorderColor}" \
            corner_radius=${barCornerRadius} \
            blur_radius=${barBlurRadius} \
            padding_left=10 \
            padding_right=10 \
            margin=0 \
            y_offset=0 \
            notch_width=200 \
            display=main \
            sticky=on \
            topmost=on

          sketchybar --default \
            icon.color="$FG_HEX" \
            label.color="$FG_HEX" \
            background.color="$SELECTION_HEX" \
            background.corner_radius=8 \
            background.height=${toString (lib.max 24 (bar.height - 6))} \
            background.border_width=1 \
            background.border_color="$MUTED_HEX" \
            background.drawing=off \
            icon.font="SF Pro:Semibold:14.0" \
            label.font="SF Pro:Semibold:13.0" \
            icon.padding_left=8 \
            icon.padding_right=6 \
            label.padding_left=6 \
            label.padding_right=8 \
            padding_left=6 \
            padding_right=6

          sketchybar --add event aerospace_workspace_change
          sketchybar --add event change-window-workspace
          sketchybar --add event aerospace_focus_change

          sketchybar --add item omanix.apple left \
            --set omanix.apple icon="􀣺" icon.color="$ACCENT_HEX" label.drawing=off background.color="$SELECTION_HEX" background.drawing=on background.corner_radius=6 click_script="open -a 'Omanix'"

          for sid in ${lib.concatStringsSep " " spaces}; do
            sketchybar --add item space.$sid left \
              --subscribe space.$sid aerospace_workspace_change change-window-workspace \
              --set space.$sid icon="$sid" icon.font="SF Pro:Bold:13.0" icon.color="$FG_HEX" label.drawing=off background.color="$SELECTION_HEX" background.corner_radius=8 background.height=${toString (lib.max 24 (bar.height - 6))} background.border_width=1 background.border_color="$MUTED_HEX" background.drawing=off padding_left=2 padding_right=2 click_script="aerospace workspace $sid" script="$HOME/.config/sketchybar/plugins/aerospace.sh $sid"
          done

          sketchybar --add item front_app left --set front_app icon.drawing=on label.color="$FG_HEX" icon.color="$ACCENT_HEX" script="$HOME/.config/sketchybar/plugins/front_app.sh" --subscribe front_app front_app_switched

          sketchybar --add item clock right --set clock update_freq=10 icon="󰥔" icon.color="$FG_HEX" label.color="$FG_HEX" background.color="$SELECTION_HEX" background.drawing=on script="$HOME/.config/sketchybar/plugins/clock.sh"
          sketchybar --add item battery right --set battery update_freq=30 icon.color="$FG_HEX" label.color="$FG_HEX" script="$HOME/.config/sketchybar/plugins/battery.sh" --subscribe battery system_woke power_source_change
          sketchybar --add item volume right --set volume icon.color="$FG_HEX" label.color="$FG_HEX" script="$HOME/.config/sketchybar/plugins/volume.sh" --subscribe volume volume_change
          sketchybar --add item wifi right --set wifi icon="󰖩" icon.color="$FG_HEX" label.drawing=off script="$HOME/.config/sketchybar/plugins/wifi.sh"

          sketchybar --default popup.background.color="$BG_HEX" popup.background.border_color="$MUTED_HEX" popup.background.corner_radius=10 popup.blur_radius=${barBlurRadius}
          ${if bar.style == "minimal" then ''sketchybar --add item separator right --set separator icon="│" icon.color="$MUTED_HEX" label.drawing=off background.drawing=off'' else ''sketchybar --add bracket barBracket "/space\..*/" --set barBracket background.color="$BG_HEX" background.border_color="$MUTED_HEX" background.corner_radius=6''}
          sketchybar --add item omanix.notification right --set omanix.notification icon="󰂚" icon.color="0xff${lib.removePrefix "#" colors.red}" label.color="$FG_HEX" background.color="$SELECTION_HEX" drawing=off

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
        # Omanix aerospace workspace indicator — theme-aware, high contrast
        if [ -f "$HOME/.config/sketchybar/colors.sh" ]; then source "$HOME/.config/sketchybar/colors.sh"; fi
        to_hex() { echo "0xff''${1#\#}"; }
        ACCENT_HEX=$(to_hex "''${OMANIX_ACCENT:-#0A7CFF}")
        FG_HEX=$(to_hex "''${OMANIX_FOREGROUND:-#1D1D1F}")
        MUTED_HEX=$(to_hex "''${OMANIX_MUTED:-#AEAEB4}")
        SELECTION_HEX=$(to_hex "''${OMANIX_SELECTION:-#E6E6EA}")
        if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
          sketchybar --set $NAME background.drawing=on background.color="$ACCENT_HEX" background.border_color="$ACCENT_HEX" icon.color="0xffffffff" icon.font="SF Pro:Bold:14.0"
        else
          if [ "$1" = "$TARGET_WORKSPACE" ] && [ -n "$TARGET_WORKSPACE" ]; then
            sketchybar --set $NAME background.drawing=on background.color="$MUTED_HEX" background.border_color="$MUTED_HEX" icon.color="0xffffffff" icon.font="SF Pro:Semibold:13.0"
          else
            sketchybar --set $NAME background.drawing=on background.color="$SELECTION_HEX" background.border_color="$MUTED_HEX" icon.color="$FG_HEX" icon.font="SF Pro:Semibold:13.0"
          fi
        fi
      '';
    };

    xdg.configFile."sketchybar/plugins/front_app.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        # Front app — shows focused app with icon (requires sketchybar-app-font)
        if [ "$SENDER" = "front_app_switched" ]; then
          sketchybar --set $NAME label="$INFO" icon="$INFO"
          if command -v icon_map.sh >/dev/null 2>&1; then
            ICON=$(icon_map.sh "$INFO" 2>/dev/null || echo "􀆔")
            sketchybar --set $NAME icon="$ICON"
          fi
        fi
      '';
    };

    xdg.configFile."sketchybar/plugins/clock.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        sketchybar --set $NAME label="$(date '+%a %d %b %H:%M')" icon="󰥔"
      '';
    };

    xdg.configFile."sketchybar/plugins/battery.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        PERCENT=$(pmset -g batt 2>/dev/null | grep -Eo "[0-9]+%" | cut -d% -f1)
        if [ -z "$PERCENT" ]; then sketchybar --set $NAME drawing=off; exit 0; fi
        if [ "$PERCENT" -gt 80 ]; then ICON="󰁹"; elif [ "$PERCENT" -gt 50 ]; then ICON="󰁿"; elif [ "$PERCENT" -gt 20 ]; then ICON="󰁾"; else ICON="󰁺"; fi
        sketchybar --set $NAME icon="$ICON" label="''${PERCENT}%" drawing=on
      '';
    };

    xdg.configFile."sketchybar/plugins/volume.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        VOL=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || echo 50)
        if [ "$VOL" = "0" ] || [ "$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)" = "true" ]; then ICON="󰸈"; else ICON="󰕾"; fi
        sketchybar --set $NAME icon="$ICON" label="''${VOL}%"
      '';
    };

    xdg.configFile."sketchybar/plugins/wifi.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        WIFI=$(networksetup -getairportnetwork en0 2>/dev/null | sed 's/You are not associated.*//')
        if [ -n "$WIFI" ]; then sketchybar --set $NAME icon="󰖩" label.drawing=off; else sketchybar --set $NAME icon="󰖪" label.drawing=off; fi
      '';
    };
  };

  # Goodies: hide the native Mac menu bar so SketchyBar is the only bar, remove window launcher friction,
  # and one-click Accessibility grant for AeroSpace. Gated by the omanix.bar/omanix.tiling enables.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # --- Hide native Mac menu bar so Omanix's SketchyBar is the only bar (no competition) ---
    if [ "${if bar.enable then "true" else "false"}" = "true" ]; then
      defaults write NSGlobalDomain _HIHideMenuBar -bool true 2>/dev/null || true
      defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false 2>/dev/null || true
      defaults write -g NSWindowShouldDragOnGesture -bool true 2>/dev/null || true
      defaults write com.apple.spaces spans-displays -bool true 2>/dev/null || true
      killall ControlCenter 2>/dev/null || true
    fi
    # Disable competing swipe/sidebar navigation regardless of tiling state
    defaults write -g AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
    defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
    defaults write com.apple.dock expose-group-by-app -bool false 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
    killall Dock 2>/dev/null || true

    # --- AeroSpace Accessibility: one-click grant when tiling is enabled ---
    if [ "${if tiling.enable then "true" else "false"}" = "true" ]; then
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
    fi
  '';
}
