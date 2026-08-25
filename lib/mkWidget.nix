# lib/mkWidget.nix — SDK for creating Omanix widgets
# Takes { name, sketchybarConfig, launchdConfig, ... } → module
# Branches on isDarwin → launchd.user.agents + sketchybar item
# Theme tokens ${colors.accent} injected at eval
# See conventions.md:5 and principles.md:10
{ lib, pkgs, config }:

{ name
, sketchybarConfig ? {}
, launchdConfig ? {}
, systemdConfig ? {}
, swiftSrc ? null
, dependencies ? []
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
  colors = import ../lib/themed.nix { inherit lib; }.getThemeColors config;
  user = config.omanix.user;
in {
  # SketchyBar item (darwin) or Quickshell item (linux)
  home-manager.users.${user}.xdg.configFile = lib.optionalAttrs isDarwin {
    "sketchybar/plugins/${name}.sh" = {
      text = ''
        #!/bin/bash
        sketchybar --set $NAME \
          icon="${sketchybarConfig.icon or ""}" \
          label="${sketchybarConfig.label or ""}" \
          icon.color="${colors.accent}" \
          label.color="${colors.foreground}"
      '';
      executable = true;
    };
  };

  # Launchd agent (darwin) or systemd service (linux)
  launchd.user.agents = lib.optionalAttrs isDarwin {
    "omanix.${name}" = {
      serviceConfig = {
        ProgramArguments = launchdConfig.ProgramArguments or [ "/bin/echo" "widget: ${name}" ];
        StartInterval = launchdConfig.StartInterval or 3600;
        KeepAlive = launchdConfig.KeepAlive or false;
        RunAtLoad = launchdConfig.RunAtLoad or false;
      } // lib.filterAttrs (n: v: n != "ProgramArguments" && n != "StartInterval" && n != "KeepAlive" && n != "RunAtLoad") launchdConfig;
    };
  };

  # Future: systemd.user.services for linux
  # systemd.user.services = lib.optionalAttrs (!isDarwin) { ... };
}
