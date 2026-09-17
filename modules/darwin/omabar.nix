{ config, lib, ... }:

{
  services.omabar = {
    enable = true;
    # Default theme already ships clock/battery/volume/wifi/media/front_app —
    # per the omabar README, only touch `items`/`components` here if you want
    # to override, not duplicate, those.
    bar.position = "top";
    bar.height = 38;
  };
}