# hosts/my-mac/default.nix — thin host overlay for this Mac
# Import ../configuration.nix + ../common.nix, then override host-specific values.
{ config, ... }: {
  imports = [ ../common.nix ];

  # Host-specific overrides (theme, widgets, packages stay in configuration.nix)
  networking.hostName = config.omanix.host;
}
