# modules/apps/custom.nix — install apps not in Homebrew
# Handles Antigravity, MKPlayer, Tiny Clips, Voicebox, World Monitor
# These apps aren't brew casks — we download .dmg and install to /Applications
{ config, lib, pkgs, ... }:

let
  cfg = config.omanix.apps;
  user = config.omanix.user;

  # App definitions
  apps = {
    "antigravity-ide" = {
      description = "Antigravity IDE (Google Agentic IDE)";
      defaultUrl = "";
    };
    "mkplayer" = {
      description = "MKPlayer (media player like VLC)";
      defaultUrl = "";
    };
    "tiny-clips" = {
      description = "Tiny Clips (video clips)";
      defaultUrl = "";
    };
    "voicebox" = {
      description = "Voicebox (voice/audio)";
      defaultUrl = "";
    };
    "world-monitor" = {
      description = "World Monitor (system monitoring)";
      defaultUrl = "";
    };
  };

  # Create install script for an app
  mkInstallScript = appName: appDesc: url: ''
    #!/bin/bash
    # Install ${appDesc}
    if [ -z "${url}" ]; then
      echo "ERROR: No download URL configured for ${appName}"
      echo "Set omanix.apps.${appName}.url in configuration.nix"
      exit 1
    fi
    echo "Installing ${appDesc}..."
    curl -L -o /tmp/${appName}.dmg "${url}"
    hdiutil attach /tmp/${appName}.dmg -mountpoint /tmp/${appName}-mnt -nobrowse -quiet
    cp -R /tmp/${appName}-mnt/*.app /Applications/ 2>/dev/null || \
      cp -R /tmp/${appName}-mnt/*/*.app /Applications/ 2>/dev/null
    hdiutil detach /tmp/${appName}-mnt -quiet
    rm /tmp/${appName}.dmg
    echo "${appDesc} installed to /Applications/"
  '';

in {
  options.omanix.apps = lib.mapAttrs' (name: app:
    lib.nameValuePair name {
      enable = lib.mkEnableOption app.description;
      url = lib.mkOption {
        type = lib.types.str;
        default = app.defaultUrl;
        description = "Download URL for ${app.description} .dmg";
      };
    }
  ) apps;

  config = {
    # Create install scripts for each enabled app
    home-manager.users.${user}.home.file = lib.mapAttrs' (name: app:
      lib.nameValuePair ".local/bin/install-${name}" {
        text = mkInstallScript name app.description cfg.${name}.url;
        executable = true;
      }
    ) (lib.filterAttrs (name: _: cfg.${name}.enable) apps);
  };
}
