# modules/theme/options.nix — theme + bar options (the green user surface)
{ lib, ... }: {
  options.omanix.bar = {
    position = lib.mkOption {
      type = lib.types.enum [ "top" "bottom" ];
      default = "top";
      description = "Bar position on screen. Flows around the notch on MacBook Pro.";
      example = "bottom";
    };

    transparent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the bar background is transparent.";
      example = true;
    };
  };
}
