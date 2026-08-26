# modules/darwin/sudo.nix — declarative sudoers for omanix
# Allows the user to run darwin-rebuild without password prompts.
# This enables the Omanix Store GUI to rebuild without osascript.
{ config, lib, ... }:

let
  cfg = config.omanix;
in
{
  options.omanix.sudo = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow the user to run darwin-rebuild without password prompts. Enables the Omanix Store GUI to rebuild.";
    };
  };

  config = lib.mkIf cfg.sudo.enable {
    security.sudo.extraConfig = ''
      # Omanix: allow ${cfg.user} to run darwin-rebuild without password
      ${cfg.user} ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild
    '';
  };
}
