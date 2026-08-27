# modules/widgets/options.nix — widget enable/disable options
# All false by default except which (the Omanix app) — Phase 06
{ lib, ... }: {
  options.omanix.widgets = {
    pomodoro.enable = lib.mkEnableOption "pomodoro timer (bar item + launchd timer + optional Swift menubar app)";
    clock.enable = lib.mkEnableOption "clock widget (bar item with date/time)";
    gui.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Omanix app (SwiftUI GUI), enabled by default";
    };
  };
}
