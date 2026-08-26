# modules/darwin/activation.nix — activation scripts for dirs not expressible as launchd
# PostgreSQL and Redis dirs are handled by services.nix
# This file is kept for future activation scripts that aren't service-related
{ config, ... }: {
  system.activationScripts.preActivation = {
    enable = true;
    text = ''
      # Future activation scripts go here
    '';
  };
}
