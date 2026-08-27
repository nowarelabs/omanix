{ lib, ... }: {
  options.omanix.widgets.gui.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Omanix app (SwiftUI GUI), enabled by default";
  };
}
