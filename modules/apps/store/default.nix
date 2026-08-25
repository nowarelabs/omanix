# modules/apps/store/default.nix — Omanix Store GUI (SwiftUI on mac, GTK on linux)
# Enabled by default (omanix.widgets.store.enable = true)
# See conventions.md:14 and principles.md:14
{ config, lib, pkgs, ... }:
let
  enabled = config.omanix.widgets.store.enable;
in {
  config = lib.mkIf enabled {
    # Launchd agent to keep Store accessible
    launchd.user.agents.omanix-store = {
      serviceConfig = {
        ProgramArguments = [ "/bin/echo" "Omanix Store is a derivation, not a daemon" ];
        KeepAlive = false;
        RunAtLoad = false;
      };
    };
  };
}
