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
    AUTO_CLEAN="${lib.boolToString config.omanix.autoClean}"
    KEEP_GENS="${toString config.omanix.keepGenerations}"
    if [[ "$AUTO_CLEAN" == "true" ]]; then
      echo "Auto-clean enabled: keeping last $KEEP_GENS generations"
      OMANIX_KEEP_GENERATIONS="$KEEP_GENS" \
        "/Users/${config.omanix.user}/.omanix/libexec/omanix-clean.sh" --keep "$KEEP_GENS" 2>&1 || true
    fi
  '';
}
