# lib/mkBarItem.nix — nix-native SketchyBar event/script system (blow users away)
# Like mkWidget but for the bar: declarative, theme-aware, hot-reloadable via `sketchybar --trigger`
# Usage in configuration.nix:
#   omanix.bar.widgets.cpu = {
#     enable = true;
#     position = "right";
#     icon = "󰘚";
#     script = "sketchybar --set $NAME label=\"$(top -l1 | awk '/CPU/')\"";
#     events = ["aerospace_workspace_change" "system_woke"];
#     updateFreq = 10;
#   };
# Or via `omanix add` / Store GUI — all via `programs.sketchybar` + `lib/themed.nix`
{ lib, pkgs, config }:

{ name
, position ? "right"
, icon ? ""
, label ? ""
, script ? ""
, events ? []
, updateFreq ? null
, padding ? 4
, background ? true
, extraArgs ? ""
}:
let
  themed = import ./themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
  user = config.omanix.user;
  # Theme-aware defaults: icon/label use foreground, background uses selection
  iconColor = colors.foreground;
  labelColor = colors.foreground;
  bgColor = colors.selection;
  pluginPath = "sketchybar/plugins/${name}.sh";
  # SketchyBar event subscribe string
  subscribeStr = lib.concatMapStringsSep " " (e: "--subscribe ${name} ${e}") events;
  # Update freq if set
  freqStr = lib.optionalString (updateFreq != null) "update_freq=${toString updateFreq}";
in {
  # Plugin script — theme-aware, uses OMANIX_* if available
  home-manager.users.${user}.xdg.configFile.${pluginPath} = lib.mkIf (config.omanix.bar.widgets.${name}.enable or true) {
    executable = true;
    text = ''
      #!/bin/bash
      # Omanix bar widget: ${name} — generated via lib/mkBarItem.nix
      # Theme: ${config.omanix.theme} | ${icon} ${label}
      if [ -f "$HOME/.config/sketchybar/colors.sh" ]; then source "$HOME/.config/sketchybar/colors.sh"; fi
      ${script}
    '';
  };

  # Item definition to be spliced into sketchybarrc
  # This is a string that desktop.nix can concat into programs.sketchybar.config
  sketchybarItem = ''
    sketchybar --add item ${name} ${position} \
      --set ${name} icon="${icon}" label="${label}" icon.color="${iconColor}" label.color="${labelColor}" background.color="${bgColor}" background.drawing=${if background then "on" else "off"} ${freqStr} ${extraArgs} script="$HOME/.config/sketchybar/plugins/${name}.sh" ${subscribeStr}
  '';
}
