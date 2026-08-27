# modules/darwin/desktop.nix — AeroSpace + SketchyBar + JankyBorders — Omanix Omakase
# World-class tiling: i3-like via AeroSpace, polished bar via SketchyBar, popping borders via JankyBorders.
# All theme-aware (lib/themed.nix) and matching the GUI app's OC palette (page #FBFBFC, card white, accent #0A7CFF, border #E6E6EA)
# References: frankcarv.com/blog/sketchy, nikitabobko.github.io/AeroSpace/goodies, mozumasu window customization, Masstronaut dotfiles
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
  sketchyColors = themed.getSketchyBarColors config;
  aerospaceColors = themed.getAerospaceColors config;
  user = config.omanix.user;
  barIsGlass = config.omanix.bar.style == "glass";
  barTransparent = config.omanix.bar.transparent || barIsGlass;
  barBlur = config.omanix.bar.blur || barIsGlass;
  toSketchy = hex: "0xff${lib.removePrefix "#" hex}";
  toSketchyAlpha = hex: alpha: "0x${alpha}${lib.removePrefix "#" hex}";
  barColor = if barTransparent then "0x00000000" else toSketchy sketchyColors.background;
  barBlurRadius = if barBlur then toString config.omanix.bar.blurRadius else "0";
  # Omakase: top bar like macOS, not floating card, so no margin/y_offset, square top
  barCornerRadius = if config.omanix.bar.style == "glass" then "10" else if config.omanix.bar.style == "modern" then "8" else "0";
  barBorderWidth = if config.omanix.bar.style == "minimal" then "0" else "1";
  barBorderColor = toSketchy sketchyColors.muted;
  barPosition = config.omanix.bar.position;
  aerospaceActiveBorder = aerospaceColors.accent;
  aerospaceInactiveBorder = aerospaceColors.muted;
  gapOuterTop = if barPosition == "top" then 32 else 10;
  gapOuterBottom = if barPosition == "bottom" then 32 else 10;
  # SketchyBar font — matches GUI's SF Pro, with app-font for icons (install via brew: sketchybar-app-font)
  iconFont = "sketchybar-app-font:Regular:14.0";
  labelFont = "SF Pro:Semibold:12.5";
in {
  # AeroSpace — Omakase i3-like, with goodies and Omakase gaps
  services.aerospace = {
    enable = true;
    settings = {
      after-startup-command = [
        "exec-and-forget sketchybar --reload"
        "exec-and-forget sketchybar"
        "exec-and-forget borders active_color=0xff${lib.removePrefix "#" aerospaceActiveBorder} inactive_color=0x40${lib.removePrefix "#" aerospaceInactiveBorder} width=5.0 style=round || true"
      ];
      after-login-command = [];
      # start-at-login is managed by launchd (services.aerospace + launchd.user.agents), not aerospace.toml itself — nix-darwin assertion
      start-at-login = false;
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
      automatically-unhide-macos-hidden-apps = false;
      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        "sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE PREV_WORKSPACE=$AEROSPACE_PREV_WORKSPACE"
      ];
      on-focus-changed = [];
      gaps = {
        inner.horizontal = 8;
        inner.vertical = 8;
        outer.left = 10;
        outer.bottom = gapOuterBottom;
        outer.top = gapOuterTop;
        outer.right = 10;
      };
      key-mapping = { preset = "qwerty"; };
      on-window-detected = [
        { "if".app-id = "com.apple.finder"; run = "layout floating"; }
        { "if".app-id = "com.apple.systempreferences"; run = "layout floating"; }
        { "if".app-id = "com.apple.ActivityMonitor"; run = "layout floating"; }
        { "if"."app-name-regex-substring" = "finder"; run = "layout floating"; }
        { "if".app-id = "com.google.Chrome"; run = "move-node-to-workspace B"; }
        { "if".app-id = "company.thebrowser.Browser"; run = "move-node-to-workspace B"; }
        { "if".app-id = "com.tinyspeck.slackmacgap"; run = "move-node-to-workspace I"; }
        { "if".app-id = "com.hnc.Discord"; run = "move-node-to-workspace M"; }
        { "if".app-id = "md.obsidian"; run = "move-node-to-workspace N"; }
        { "if".app-id = "notion.id"; run = "move-node-to-workspace W"; }
        { "if".app-id = "com.github.wez.wezterm"; run = "move-node-to-workspace T"; }
        { "if".app-id = "com.apple.Terminal"; run = "move-node-to-workspace T"; }
        { "if".app-id = "com.mitchellh.ghostty"; run = "move-node-to-workspace T"; }
      ];
      mode.main.binding = {
        alt-h = "focus left"; alt-j = "focus down"; alt-k = "focus up"; alt-l = "focus right";
        alt-shift-h = "move left"; alt-shift-j = "move down"; alt-shift-k = "move up"; alt-shift-l = "move right";
        alt-minus = "resize smart -50"; alt-equal = "resize smart +50"; alt-shift-minus = "resize smart -50"; alt-shift-equal = "resize smart +50";
        alt-1 = "workspace 1"; alt-2 = "workspace 2"; alt-3 = "workspace 3"; alt-4 = "workspace 4"; alt-5 = "workspace 5"; alt-6 = "workspace 6"; alt-7 = "workspace 7"; alt-8 = "workspace 8"; alt-9 = "workspace 9";
        alt-a = "workspace A"; alt-b = "workspace B"; alt-c = "workspace C"; alt-d = "workspace D"; alt-e = "workspace E"; alt-g = "workspace G"; alt-i = "workspace I"; alt-m = "workspace M"; alt-n = "workspace N"; alt-o = "workspace O"; alt-p = "workspace P"; alt-q = "workspace Q"; alt-r = "workspace R"; alt-s = "workspace S"; alt-t = "workspace T"; alt-u = "workspace U"; alt-v = "workspace V"; alt-w = "workspace W"; alt-x = "workspace X"; alt-y = "workspace Y"; alt-z = "workspace Z";
        alt-shift-1 = ''move-node-to-workspace 1''; alt-shift-2 = ''move-node-to-workspace 2''; alt-shift-3 = ''move-node-to-workspace 3''; alt-shift-4 = ''move-node-to-workspace 4''; alt-shift-5 = ''move-node-to-workspace 5''; alt-shift-6 = ''move-node-to-workspace 6''; alt-shift-7 = ''move-node-to-workspace 7''; alt-shift-8 = ''move-node-to-workspace 8''; alt-shift-9 = ''move-node-to-workspace 9'';
        alt-tab = "workspace-back-and-forth"; alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
        alt-f = "fullscreen"; alt-slash = "layout tiles horizontal vertical"; alt-comma = "layout accordion horizontal vertical";
        alt-space = ''exec-and-forget open -a "Omanix"''; # Omanix launcher (also: open -a Omanix, or Super → Omanix)
        alt-shift-semicolon = "mode service"; alt-shift-space = "layout floating tiling";
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

  # SketchyBar — via home-manager programs.sketchybar (nix-native, event-driven, blow-away)
  # See https://github.com/nix-community/home-manager/blob/master/modules/programs/sketchybar.nix
  # and https://sketchybar.org — we use programs.sketchybar.config (bash) + extraPackages + launchd
  home-manager.users.${user} = lib.mkIf (user != "") {
    programs.sketchybar = {
      enable = true;
      configType = "bash";
      extraPackages = with pkgs; [ jq sketchybar-app-font ];
      service.enable = true;
      config = {
        text = ''
          #!/bin/bash
          # Omanix SketchyBar — Omakase, generated via lib/themed.nix + omanix.bar
          # Theme: ${config.omanix.theme} | ${sketchyColors.background} -> ${sketchyColors.foreground} | accent ${sketchyColors.accent}
          # Matches GUI app: page #FBFBFC, card white, border #E6E6EA, text #1D1D1F
          # Event-driven: aerospace_workspace_change, front_app_switched, system_woke, etc.

          # Load theme colors
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

          # Bar — Omakase menu bar replacement, 32px at top edge, no Mac competition
          sketchybar --bar \
            position="${barPosition}" \
            height=32 \
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
            topmost=off

          sketchybar --default \
            icon.color="$FG_HEX" \
            label.color="$FG_HEX" \
            background.color="$SELECTION_HEX" \
            background.corner_radius=8 \
            background.height=26 \
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

          for sid in 1 2 3 4 5 6 7 8 9 T B I M N W; do
            sketchybar --add item space.$sid left \
              --subscribe space.$sid aerospace_workspace_change change-window-workspace \
              --set space.$sid icon="$sid" icon.font="SF Pro:Bold:13.0" icon.color="$FG_HEX" label.drawing=off background.color="$SELECTION_HEX" background.corner_radius=8 background.height=26 background.border_width=1 background.border_color="$MUTED_HEX" background.drawing=off padding_left=2 padding_right=2 click_script="aerospace workspace $sid" script="$HOME/.config/sketchybar/plugins/aerospace.sh $sid"
          done

          sketchybar --add item front_app left --set front_app icon.drawing=on label.color="$FG_HEX" icon.color="$ACCENT_HEX" script="$HOME/.config/sketchybar/plugins/front_app.sh" --subscribe front_app front_app_switched

          sketchybar --add item clock right --set clock update_freq=10 icon="󰥔" icon.color="$FG_HEX" label.color="$FG_HEX" background.color="$SELECTION_HEX" background.drawing=on script="$HOME/.config/sketchybar/plugins/clock.sh"
          sketchybar --add item battery right --set battery update_freq=30 icon.color="$FG_HEX" label.color="$FG_HEX" script="$HOME/.config/sketchybar/plugins/battery.sh" --subscribe battery system_woke power_source_change
          sketchybar --add item volume right --set volume icon.color="$FG_HEX" label.color="$FG_HEX" script="$HOME/.config/sketchybar/plugins/volume.sh" --subscribe volume volume_change
          sketchybar --add item wifi right --set wifi icon="󰖩" icon.color="$FG_HEX" label.drawing=off script="$HOME/.config/sketchybar/plugins/wifi.sh"

          sketchybar --default popup.background.color="$BG_HEX" popup.background.border_color="$MUTED_HEX" popup.background.corner_radius=10 popup.blur_radius=${barBlurRadius}
          ${if config.omanix.bar.style == "minimal" then ''sketchybar --add item separator right --set separator icon="│" icon.color="$MUTED_HEX" label.drawing=off background.drawing=off'' else ''sketchybar --add bracket barBracket "/space\..*/" --set barBracket background.color="$BG_HEX" background.border_color="$MUTED_HEX" background.corner_radius=6''}
          sketchybar --add item omanix.notification right --set omanix.notification icon="󰂚" icon.color="0xff${lib.removePrefix "#" colors.red}" label.color="$FG_HEX" background.color="$SELECTION_HEX" drawing=off

          # Omanix widgets — lib/mkBarItem / lib/mkWidget event system (nix → sketchybar --trigger)
          # Example: omanix.bar.widgets.cpu via mkBarItem, or pomodoro via mkWidget
          for plugin in "$HOME/.config/sketchybar/plugins/"omanix-*.sh "$HOME/.config/sketchybar/plugins/"pomodoro.sh "$HOME/.config/sketchybar/plugins/"clock.sh; do
            [ -x "$plugin" ] && [ -f "$plugin" ] && source "$plugin" 2>/dev/null || true
          done

          sketchybar --update
        '';
      };
    };

    # Also write the full Omakase aerospace.toml via home-manager for transparent customization
    # This file is the source of truth for keybindings and window rules — theme-aware and Omakase
    # start-at-login is false here as well — launchd (nix-darwin) handles login
    xdg.configFile."aerospace/aerospace.toml" = {
      text = ''
        # Omanix AeroSpace — Omakase, theme-aware, generated via lib/themed.nix
        # Theme: ${config.omanix.theme} | accent ${aerospaceActiveBorder} muted ${aerospaceInactiveBorder}
        # Gaps tuned for SketchyBar + JankyBorders — do not edit, set omanix.* in configuration.nix
        after-login-command = []
        after-startup-command = ['exec-and-forget sketchybar --reload', 'exec-and-forget sketchybar', 'exec-and-forget borders active_color=0xff${lib.removePrefix "#" aerospaceActiveBorder} inactive_color=0x40${lib.removePrefix "#" aerospaceInactiveBorder} width=5.0 style=round || true']
        start-at-login = false
        enable-normalization-flatten-containers = true
        enable-normalization-opposite-orientation-for-nested-containers = true
        accordion-padding = 30
        default-root-container-layout = 'tiles'
        default-root-container-orientation = 'auto'
        on-focused-monitor-changed = ['move-mouse monitor-lazy-center']
        automatically-unhide-macos-hidden-apps = false
        exec-on-workspace-change = ['/bin/bash', '-c', 'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE PREV_WORKSPACE=$AEROSPACE_PREV_WORKSPACE']
        [key-mapping]
        preset = 'qwerty'
        [gaps]
        inner.horizontal = 8
        inner.vertical = 8
        outer.left = 10
        outer.bottom = ${toString gapOuterBottom}
        outer.top = ${toString gapOuterTop}
        outer.right = 10

        # --- Floating windows (goodies: Finder, Settings, etc.) ---
        [[on-window-detected]]
        if.app-id = 'com.apple.finder'
        run = 'layout floating'
        [[on-window-detected]]
        if.app-id = 'com.apple.systempreferences'
        run = 'layout floating'
        [[on-window-detected]]
        if.app-id = 'com.apple.ActivityMonitor'
        run = 'layout floating'
        [[on-window-detected]]
        if.app-name-regex-substring = 'finder'
        run = 'layout floating'

        # --- Workspace assignments (Masstronaut style) ---
        [[on-window-detected]]
        if.app-id = 'com.google.Chrome'
        run = 'move-node-to-workspace B'
        [[on-window-detected]]
        if.app-id = 'company.thebrowser.Browser'
        run = 'move-node-to-workspace B'
        [[on-window-detected]]
        if.app-id = 'com.tinyspeck.slackmacgap'
        run = 'move-node-to-workspace I'
        [[on-window-detected]]
        if.app-id = 'com.hnc.Discord'
        run = 'move-node-to-workspace M'
        [[on-window-detected]]
        if.app-id = 'md.obsidian'
        run = 'move-node-to-workspace N'
        [[on-window-detected]]
        if.app-id = 'notion.id'
        run = 'move-node-to-workspace W'
        [[on-window-detected]]
        if.app-id = 'com.github.wez.wezterm'
        run = 'move-node-to-workspace T'
        [[on-window-detected]]
        if.app-id = 'com.apple.Terminal'
        run = 'move-node-to-workspace T'
        [[on-window-detected]]
        if.app-id = 'com.mitchellh.ghostty'
        run = 'move-node-to-workspace T'

        # --- Main mode: vim hjkl + workspaces 1-9 ---
        [mode.main.binding]
        # Focus with alt-h/j/k/l (ergonomic, frankcarv)
        alt-h = 'focus left'
        alt-j = 'focus down'
        alt-k = 'focus up'
        alt-l = 'focus right'
        # Move with alt-shift-h/j/k/l
        alt-shift-h = 'move left'
        alt-shift-j = 'move down'
        alt-shift-k = 'move up'
        alt-shift-l = 'move right'
        # Resize smart
        alt-minus = 'resize smart -50'
        alt-equal = 'resize smart +50'
        alt-shift-minus = 'resize smart -50'
        alt-shift-equal = 'resize smart +50'
        # Workspaces 1-9 (instant, no animation)
        alt-1 = 'workspace 1'
        alt-2 = 'workspace 2'
        alt-3 = 'workspace 3'
        alt-4 = 'workspace 4'
        alt-5 = 'workspace 5'
        alt-6 = 'workspace 6'
        alt-7 = 'workspace 7'
        alt-8 = 'workspace 8'
        alt-9 = 'workspace 9'
        alt-a = 'workspace A'
        alt-b = 'workspace B'
        alt-c = 'workspace C'
        alt-d = 'workspace D'
        alt-e = 'workspace E'
        alt-g = 'workspace G'
        alt-i = 'workspace I'
        alt-m = 'workspace M'
        alt-n = 'workspace N'
        alt-o = 'workspace O'
        alt-p = 'workspace P'
        alt-q = 'workspace Q'
        alt-r = 'workspace R'
        alt-s = 'workspace S'
        alt-t = 'workspace T'
        alt-u = 'workspace U'
        alt-v = 'workspace V'
        alt-w = 'workspace W'
        alt-x = 'workspace X'
        alt-y = 'workspace Y'
        alt-z = 'workspace Z'
        # Move to workspace (with sketchybar trigger, Masstronaut)
        alt-shift-1 = ['move-node-to-workspace 1', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=1 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-2 = ['move-node-to-workspace 2', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=2 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-3 = ['move-node-to-workspace 3', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=3 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-4 = ['move-node-to-workspace 4', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=4 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-5 = ['move-node-to-workspace 5', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=5 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-6 = ['move-node-to-workspace 6', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=6 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-7 = ['move-node-to-workspace 7', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=7 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-8 = ['move-node-to-workspace 8', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=8 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        alt-shift-9 = ['move-node-to-workspace 9', 'exec-and-forget sketchybar --trigger change-window-workspace TARGET_WORKSPACE=9 FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE']
        # Layout, fullscreen, back-and-forth — plus Omanix launcher
        alt-tab = 'workspace-back-and-forth'
        alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'
        alt-f = 'fullscreen'
        alt-slash = 'layout tiles horizontal vertical'
        alt-comma = 'layout accordion horizontal vertical'
        alt-space = 'exec-and-forget open -a "Omanix"'
        alt-shift-semicolon = 'mode service'
        alt-shift-space = 'layout floating tiling'
        cmd-h = []  # disable hide (goodies#10)
        cmd-alt-h = []

        [mode.service.binding]
        esc = ['reload-config', 'mode main']
        r = ['flatten-workspace-tree', 'mode main']
        f = ['layout floating tiling', 'mode main']
        backspace = ['close-all-windows-but-current', 'mode main']

        [mode.resize.binding]
        h = 'resize width -50'
        j = 'resize height +50'
        k = 'resize height -50'
        l = 'resize width +50'
        enter = 'mode main'
        esc = 'mode main'
      '';
    };

    # AeroSpace workspace helper — high-contrast, like GUI selected card, 13px bold
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
            # Inactive: pill with selection bg + FG text (visible on both light/dark), not transparent
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
          # Use app-font if available: icon is app name -> ligature
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

  # Goodies: window dragging, hide Mac bar/tray/swipe, and one-click Accessibility
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # --- Hide native Mac bar/tray so SketchyBar is the only bar (no competition) ---
    defaults write NSGlobalDomain _HIHideMenuBar -bool true 2>/dev/null || true
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false 2>/dev/null || true
    defaults write -g NSWindowShouldDragOnGesture -bool true 2>/dev/null || true
    defaults write com.apple.spaces spans-displays -bool true 2>/dev/null || true
    # Disable competing swipe between spaces/pages
    defaults write -g AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
    defaults write com.apple.dock expose-group-by-app -bool false 2>/dev/null || true
    defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false 2>/dev/null || true
    # Apply without logout (ControlCenter for menu bar, Dock for spaces)
    killall SystemUIServer 2>/dev/null || true
    killall ControlCenter 2>/dev/null || true
    killall Dock 2>/dev/null || true

    # --- AeroSpace Accessibility: one-click, not "may need" ---
    # Check if AeroSpace can list workspaces (fails without Accessibility)
    AEROSPACE_BIN=$(command -v aerospace 2>/dev/null || echo "/opt/homebrew/bin/aerospace")
    if [ -x "$AEROSPACE_BIN" ]; then
      if ! "$AEROSPACE_BIN" list-workspaces --all >/dev/null 2>&1; then
        echo ""
        echo "┌─────────────────────────────────────────────────────────┐"
        echo "│  Omanix: Grant Accessibility to AeroSpace (one click)  │"
        echo "│  Click 'Open Settings' → + → add AeroSpace → Done     │"
        echo "└─────────────────────────────────────────────────────────┘"
        # Try automated prompt with dialog (no manual file touch)
        if command -v osascript >/dev/null 2>&1; then
          osascript -e 'display dialog "Omanix needs Accessibility for AeroSpace to tile windows.\n\nClick Open Settings → + → add AeroSpace." buttons {"Open Settings", "Later"} default button "Open Settings" with title "Omanix — AeroSpace"' 2>/dev/null | grep -q "Open Settings" && \
          open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
        else
          open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true
        fi
        # Also try CLI helper if user runs with sudo
        echo "Tip: run 'omanix permissions grant' to auto-add (sudo) or re-run 'omanix rebuild' after granting"
      else
        echo "AeroSpace Accessibility: OK"
      fi
    fi
    # SketchyBar app-font hint
    if ! ls ~/Library/Fonts/*sketchybar* >/dev/null 2>&1 && ! ls /Library/Fonts/*sketchybar* >/dev/null 2>&1; then
      echo "Tip: Install sketchybar-app-font for icons: brew install --cask font-sketchybar-app-font (tap FelixKratz/formulae)"
    fi
  '';
}
