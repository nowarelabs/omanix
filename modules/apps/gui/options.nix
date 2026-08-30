{ lib, ... }: {
  options.omanix.widgets.gui.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Omanix app (SwiftUI GUI), enabled by default";
  };
  options.omanix.widgets.store.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Omanix Store widget, disabled by default";
  };
  options.omanix.widgets.pomodoro.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Pomodoro Timer widget, disabled by default";
  };
  options.omanix.widgets.clock.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Clock widget, disabled by default";
  };
}
