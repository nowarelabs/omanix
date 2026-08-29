# modules/darwin/omatiles.nix — Omanix Omatiles: native window tiling module (inside the Omanix app)
# Launches the app in "--omatiles" mode at login and emits Accessibility guidance on rebuild.
# Controlled declaratively from themes/options.nix:
#   omanix.omatiles.*  (enable, layout, gapInner, gapOuter, bindings, watch, floatingApps)
{ config, lib, pkgs, ... }:
{
  # Launch the Omanix app in "Omatiles module mode" at login, restarted if it dies.
  # Pinned nix-darwin (52d0615) launchd.agents.<name> only takes serviceConfig, so gating
  # is done at eval time with lib.mkIf (see omabar.nix).
  launchd.agents.omatiles = lib.mkIf config.omanix.omatiles.enable {
    serviceConfig = {
      Label = "om.omanix.omatiles";
      ProgramArguments = [ "/Applications/Omanix.app/Contents/MacOS/Omanix" "--omatiles" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # Guidance only — the Omanix app itself drives the Accessibility permission prompt when
  # it starts. Gated at eval time so no constant conditionals land in the activation script.
  system.activationScripts.postActivation.text = lib.mkAfter (
    lib.optionalString config.omanix.omatiles.enable ''
      echo "Omanix Omatiles: window tiling enabled — grant Accessibility to Omanix if prompted" 2>/dev/null || true
    ''
  );
}