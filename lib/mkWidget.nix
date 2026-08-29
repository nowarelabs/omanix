# lib/mkWidget.nix — SDK for creating Omanix widgets
# Takes { name, launchdConfig, systemdConfig, ... } → module
# Branches on isDarwin → launchd.user.agents
# Theme tokens ${colors.accent} injected at eval
# The macOS menu bar and window tiling are native modules inside the Omanix app
# (Modules/Omabar, Modules/Omatiles) — no sketchybar item generation here.
# See conventions.md:5 and principles.md:10
{ lib, pkgs, config }:

{ name
, launchdConfig ? {}
, systemdConfig ? {}
, swiftSrc ? null
, dependencies ? []
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
in {
  # Launchd agent (mac) — the widget body itself. Usually paired with a Swift app
  # via lib/mkApp (swiftSrc) or a bar item registered with the native Omabar module.
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
