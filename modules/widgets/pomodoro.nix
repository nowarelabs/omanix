# modules/widgets/pomodoro.nix — first widget: pomodoro timer
# Uses lib/mkWidget: sketchybar item + launchd timer
# See principles.md:10 for the widget contract
{ config, lib, pkgs, ... }:
let
  enabled = config.omanix.widgets.pomodoro.enable;
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
in {
  config = lib.mkIf enabled {
    # SketchyBar item
    xdg.configFile."sketchybar/plugins/pomodoro.sh" = {
      text = ''
        #!/bin/bash
        sketchybar --set pomodoro \
          icon="󰔟" \
          label="25:00" \
          icon.color="${colors.accent}" \
          label.color="${colors.foreground}"
      '';
      executable = true;
    };

    # Launchd agent — ticks every 60 seconds
    launchd.user.agents.omanix-pomodoro = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.bash}/bin/bash"
          "-c"
          "sketchybar --set pomodoro label=\$(( \$(date +%s) % 3600 / 60 )):00"
        ];
        StartInterval = 60;
        KeepAlive = false;
        RunAtLoad = true;
      };
    };
  };
}
