# modules/desktop/workspaces.nix — Owin declarative workspace mappings
# Writes a Nix-generated JSON map that the Swift AXUI sink consumes without a daemon.
# See modules/theme/options.nix: omanix.workspaces / omanix.owin and the brief's
# "Deterministic Workspace Mappings" / "Direct macOS Event Sink" sections.
{ config, lib, pkgs, ... }:
let
  user = config.omanix.user;
  workspaces = config.omanix.workspaces;
  owinEnabled = config.omanix.owin.enable or false;
in {
  config = lib.mkIf (user != "" && (workspaces != {} || owinEnabled)) {
    home-manager.users.${user} = {
      xdg.configFile."omanix/workspaces.json" = {
        text = builtins.toJSON {
          enabled = owinEnabled;
          defaultLayout = config.omanix.owin.defaultLayout or "bsp";
          workspaces = workspaces;
        };
      };
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      mkdir -p "$HOME/.config/omanix" 2>/dev/null || mkdir -p "/Users/${user}/.config/omanix" 2>/dev/null || true
      cat > "/Users/${user}/.config/omanix/workspaces.json" <<'WORKSPACESJSON'
      ${builtins.toJSON { enabled = owinEnabled; defaultLayout = config.omanix.owin.defaultLayout or "bsp"; workspaces = workspaces; }}
      WORKSPACESJSON
      chown ${user}:staff "/Users/${user}/.config/omanix/workspaces.json" 2>/dev/null || true
      if ${if owinEnabled then "true" else "false"}; then
        echo "[workspaces] Owin enabled — wrote ${builtins.toJSON workspaces} to workspaces.json"
      fi
    '';
  };
}
