# Temporary stub — theme engine will be implemented in Phase 03
# For now, omanix.theme is a typed string option (modules/core/options.nix)
# and themes/ will be vendored from omarchy-mac in Phase 03
{ config, lib, ... }: {
  # Phase 03 will add:
  # options.omanix.bar = { ... };
  # lib.omanixTheme = builtins.fromTOML (builtins.readFile ../../themes/${config.omanix.theme}/colors.toml);
}
