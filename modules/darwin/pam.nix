# modules/darwin/pam.nix — Touch ID + primary user (darwin-only)

{ config, ... }: {
  security.pam.services.sudo_local.touchIdAuth = true;

  system.primaryUser = config.omanix.user;

  users.users.${config.omanix.user} = {
    name = config.omanix.user;
    home = "/Users/${config.omanix.user}";
  };
}
