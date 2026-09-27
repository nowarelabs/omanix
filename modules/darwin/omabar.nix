{ config, lib, ... }:

{
  services.omabar = {
    # Single source of truth: the GUI and `omanix state set` write
    # `omanix.omabar.enable` into the generated state.nix, and this maps it onto
    # the module. Nothing reads or writes `services.omabar.enable` directly.
    enable = config.omanix.omabar.enable;
    # Default theme already ships clock/battery/volume/wifi/media/front_app —
    # per the omabar README, only touch `items`/`components` here if you want
    # to override, not duplicate, those.
    bar = {
      position = "top";

      # The bar lives *in* the native menu bar band, not floating below it.
      # 38 is this display's actual band: NSScreen.mainScreen.frame is
      # 1512x982 and visibleFrame is 1512x944, so frame.height - visibleFrame
      # = 38. (NSStatusBar.thickness reports 22 here, but that is the compact
      # status-item height, not the band the menu bar actually occupies.)
      height = 38;

      # Flush with the top of the display. bar.c computes the top-bar origin
      # as y_offset + notch offset, so both must be zero for the bar to start
      # at the very top.
      y_offset = 0;
      margin = 0;

      # notch_auto_offset must be cleared: by default bar_get_frame() pushes a
      # top bar below the camera housing whenever notch_offset is 0, which is
      # what put it under the notch. notch_width stays 0 (auto-detect), so
      # centre-positioned items are still laid out around the notch.
      notch_auto_offset = false;

      # A full-width strip with rounded corners and a drop shadow reads as a
      # floating box, not a menu bar.
      corner_radius = 0;
      border_width = 0;
      shadow = false;
    };
  };
}
