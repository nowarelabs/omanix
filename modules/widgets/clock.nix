# modules/widgets/clock.nix — second widget: clock
# Proves the pattern scales beyond pomodoro
{ config, lib, pkgs, ... }:
let
  enabled = config.omanix.widgets.clock.enable;
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
in {
  config = lib.mkIf enabled {
    # SketchyBar item
    home-manager.users.${config.omanix.user}.xdg.configFile."sketchybar/plugins/clock.sh" = {
      text = ''
        #!/bin/bash
        sketchybar --set clock \
          icon="󰥔" \
          label="$(date '+%H:%M')" \
          icon.color="${colors.accent}" \
          label.color="${colors.foreground}"
      '';
      executable = true;
    };

    # Launchd agent — updates every 30 seconds
    launchd.user.agents.omanix-clock = {
      serviceConfig = {
        ProgramArguments = [
          "${pkgs.bash}/bin/bash"
          "-c"
          "sketchybar --set clock label=\$(date '+%H:%M')"
        ];
        StartInterval = 30;
        KeepAlive = false;
        RunAtLoad = true;
      };
    };
  };
}
