# modules/darwin/omatiles.nix — Omanix Omatiles: bridge onto macOS Sequoia's built-in window tiling
# Launches the app in "--omatiles" mode at login (registers the global ⌘⌥ tiling bindings) and
# declaratively enables macOS's own Window Management preferences (drag-to-edge, ⌃⌥+arrow
# keyboard tiling, tiled margins) via com.apple.WindowManager defaults.
# Controlled declaratively from themes/options.nix:
#   omanix.omatiles.*  (enable, bindings, enableEdgeDrag, enableKeyboardShortcuts, enableMargins)
{ config, lib, pkgs, ... }:
{
  # Launch the Omanix app in "Omatiles module mode" at login, restarted if it dies.
  # Runs as a PER-USER agent (launchd.user.agents, same as services.nix) so the
  # module shares the GUI's Accessibility permission instead of needing its own
  # root grant. NOTE: on the pinned nix-darwin (52d0615) launchd.*.agents.<name>
  # only takes serviceConfig — there is no top-level `enable`/`runAtLoad`
  # `keepAlive`/`program`/`args`, so gating is done at eval time with lib.mkIf.
  launchd.user.agents.omatiles = lib.mkIf config.omanix.omatiles.enable {
    serviceConfig = {
      Label = "om.omanix.omatiles";
      ProgramArguments = [ "/Applications/Omanix.app/Contents/MacOS/Omanix" "--omatiles" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  # Declarative Windows Management preferences. macOS Sequoia's built-in tiling lives in
  # System Settings → Desktop & Dock → Window management; these defaults are what the
  # System Settings pane toggles. Built conditionally at eval time so the rendered script
  # has no constant conditionals (shellcheck SC2050 → build failure).
  system.activationScripts.postActivation.text = lib.mkAfter (
    (lib.optionalString config.omanix.omatiles.enableEdgeDrag ''
      # Drag a window to a screen edge to tile it
      defaults write com.apple.WindowManager EnableTilingByEdgeDrag -bool true 2>/dev/null || true
    '') +
    (lib.optionalString config.omanix.omatiles.enableKeyboardShortcuts ''
      # ⌃⌥+arrow keyboard tiling (the shortcuts Omatiles re-binds to ⌘⌥+arrow)
      defaults write com.apple.WindowManager EnableTilingWithAccelerator -bool true 2>/dev/null || true
    '') +
    (lib.optionalString config.omanix.omatiles.enableMargins ''
      # Keep a margin between tiled windows
      defaults write com.apple.WindowManager EnableTiledWindowMargins -bool true 2>/dev/null || true
    '') +
    # Guidance only — the Omanix app itself drives the Accessibility permission prompt when
    # it starts. Gated at eval time so no constant conditionals land in the activation script.
    (lib.optionalString config.omanix.omatiles.enable ''
      killall WindowManager 2>/dev/null || true
      echo "Omanix Omatiles: native tiling ready — grant Accessibility to Omanix to enable the ⌘⌥ bindings" 2>/dev/null || true
    '')
  );
}