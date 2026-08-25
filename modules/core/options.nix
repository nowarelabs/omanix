# modules/core/options.nix — typed options for omanix.* (green user sees these in configuration.nix)
{ lib, ... }: {
  options.omanix.host = lib.mkOption {
    type = lib.types.str;
    default = "Vances-MacBook-Pro";
    description = "Machine hostname. Set via `scutil --get LocalHostName`. Used by `darwinConfigurations.<host>` and `networking.hostName`.";
    example = "work-mac";
  };

  options.omanix.user = lib.mkOption {
    type = lib.types.str;
    default = "vanceworks";
    description = "Primary user. Set via `whoami`. Used by `system.primaryUser`, `users.users`, and activation scripts.";
    example = "yourname";
  };

  options.omanix.theme = lib.mkOption {
    type = lib.types.enum [ "tokyo-night" "catppuccin" ];
    default = "tokyo-night";
    description = "Bar, terminal, and app theme. Rendered at build time via lib/themed.nix. Preview via Store or `overlays/` without editing colors.toml.";
    example = "catppuccin";
  };
}
