{ config, lib, ... }:

{
  services.omabar = {
    enable = true;
    # Default theme already ships clock/battery/volume/wifi/media/front_app —
    # per the omabar README, only touch `items`/`components` here if you want
    # to override, not duplicate, those.
    #
    # `bar.height` is deliberately not set: the theme's 44 is what the
    # floating bar was designed and visually tuned against (the space chips
    # are ~24pt wide). Pinning it here only makes the bar drift out of sync
    # with omabar's own redesigns.
    bar.position = "top";
  };
}