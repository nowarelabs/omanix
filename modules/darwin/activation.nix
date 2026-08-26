# modules/darwin/activation.nix — activation scripts for dirs not expressible as launchd
# PostgreSQL and Redis dirs are handled by services.nix
# This file is kept for future activation scripts that aren't service-related
{ config, lib, ... }: {
  system.activationScripts.preActivation = {
    enable = true;
    text = ''
      # Future activation scripts go here
    '';
  };

  # Auto-clean old generations after rebuild if enabled
  system.activationScripts.postActivation.text = lib.mkAfter ''
    if [[ "${lib.boolToString config.omanix.autoClean}" == "true" ]]; then
      echo "Auto-clean enabled: keeping last ${toString config.omanix.keepGenerations} generations"
      OMANIX_KEEP_GENERATIONS="${toString config.omanix.keepGenerations}" \
        "/Users/${config.omanix.user}/.omanix/lib/omanix-clean.sh" --keep "${toString config.omanix.keepGenerations}" 2>&1 || true
    fi
  '';
}
