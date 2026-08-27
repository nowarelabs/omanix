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
    type = lib.types.enum [
      "omanix"
      "tokyo-night"
      "catppuccin"
      "gruvbox"
      "everforest"
      "kanagawa"
      "rose-pine"
      "nord"
      "dracula"
      "solarized-dark"
      "one-dark"
      "matte-black"
      "horizon"
    ];
    default = "omanix";
    description = "Bar, terminal, and app theme. Rendered at build time via lib/themed.nix. 'omanix' is the signature light Omakase (OC palette #FBFBFC/#0A7CFF) matching the GUI app. See `ls themes/` and docs/themes.md. Preview via Store or overlays/ without editing colors.toml.";
    example = "catppuccin";
  };

  options.omanix.homebrew.cleanup = lib.mkOption {
    type = lib.types.enum [ "uninstall" "zap" "none" ];
    default = "uninstall";
    description = "Homebrew onActivation cleanup mode. 'uninstall' removes brews/casks we added. 'zap' removes all data too. 'none' leaves everything alone.";
    example = "none";
  };

  # --- Maintenance options ---

  options.omanix.keepGenerations = lib.mkOption {
    type = lib.types.ints.positive;
    default = 5;
    description = "Number of system generations to keep when running 'omanix clean'. Older generations are deleted to free disk space.";
    example = 10;
  };

  options.omanix.autoClean = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Automatically clean old generations after each rebuild. Uses omanix.keepGenerations to determine how many to keep.";
  };

  options.omanix.keepLogsDays = lib.mkOption {
    type = lib.types.ints.positive;
    default = 30;
    description = "Number of days to keep log files in ~/.omanix/logs/. Older logs are deleted during 'omanix clean'.";
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
