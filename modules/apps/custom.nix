# modules/apps/custom.nix — apps not in Homebrew
# Clean DX: just set enable + url, omanix handles install/uninstall
{ config, lib, pkgs, ... }:

let
  cfg = config.omanix.apps;
  user = config.omanix.user;
  mkCustomApp = import ../../lib/mkCustomApp.nix { inherit lib pkgs; };

  # Define all available custom apps
  apps = {
    "antigravity-ide" = {
      description = "Antigravity IDE (Google Agentic IDE)";
      url = "";
    };
    "mkplayer" = {
      description = "MKPlayer (media player like VLC)";
      url = "";
    };
    "tiny-clips" = {
      description = "Tiny Clips (video clips)";
      url = "";
    };
    "voicebox" = {
      description = "Voicebox (voice/audio)";
      url = "";
    };
    "world-monitor" = {
      description = "World Monitor (system monitoring)";
      url = "";
    };
  };

  # Filter to only enabled apps
  enabledApps = lib.filterAttrs (name: _: cfg.${name}.enable) apps;

  # Generate install/uninstall files for each enabled app
  appFiles = lib.concatMapAttrs (name: app:
    let result = mkCustomApp {
      inherit name;
      inherit (app) description url;
    };
    in result.installFile
  ) enabledApps;

in {
  options.omanix.apps = lib.mapAttrs' (name: app:
    lib.nameValuePair name {
      enable = lib.mkEnableOption app.description;
      url = lib.mkOption {
        type = lib.types.str;
        default = app.url;
        description = "Download URL for ${app.description}";
      };
    }
  ) apps;

  config = {
    home-manager.users.${user}.home.file = appFiles;
  };
}
