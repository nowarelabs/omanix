# modules/core/options.nix — typed options for omanix.* (green user sees these in configuration.nix)
{ lib, config, ... }: {
  options.omanix.host = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Machine hostname. Set via `scutil --get LocalHostName`. Used by `darwinConfigurations.<host>` and `networking.hostName`.";
    example = "work-mac";
  };

  options.omanix.user = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Primary user. Set via `whoami`. Used by `system.primaryUser`, `users.users`, and activation scripts.";
    example = "yourname";
  };

  options.omanix.theme = lib.mkOption {
    type = lib.types.enum [ "tokyo-night" "catppuccin" ];
    default = "tokyo-night";
    description = "Bar, terminal, and app theme. Rendered at build time via lib/themed.nix. Preview via Store or `overlays/` without editing colors.toml.";
    example = "catppuccin";
  };

  options.omanix.homebrew.cleanup = lib.mkOption {
    type = lib.types.enum [ "uninstall" "zap" "none" ];
    default = "uninstall";
    description = "Homebrew onActivation cleanup mode. 'uninstall' removes brews/casks we added. 'zap' removes all data too. 'none' leaves everything alone.";
    example = "none";
  };

  config.assertions = [
    {
      assertion = config.omanix.host != "";
      message = "omanix.host must be set in configuration.nix (e.g., omanix.host = \"my-mac\";)";
    }
    {
      assertion = config.omanix.user != "";
      message = "omanix.user must be set in configuration.nix (e.g., omanix.user = \"yourname\";)";
    }
  ];
}
