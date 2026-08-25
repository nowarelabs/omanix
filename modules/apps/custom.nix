# modules/apps/custom.nix — install apps not in Homebrew
# Handles Antigravity, MKPlayer, Tiny Clips, Voicebox, World Monitor
# These apps aren't brew casks — we download .dmg and install to /Applications
{ config, lib, pkgs, ... }:

let
  cfg = config.omanix.apps;

  # App definitions — URLs are placeholders, user must verify
  apps = {
    "Antigravity IDE" = {
      description = "Google Agentic IDE";
      url = ""; # User must provide download URL
      type = "dmg";
    };
    "MKPlayer" = {
      description = "Media player (like VLC)";
      url = "";
      type = "dmg";
    };
    "Tiny Clips" = {
      description = "Video clips tool";
      url = "";
      type = "dmg";
    };
    "Voicebox" = {
      description = "Voice/audio tool";
      url = "";
      type = "dmg";
    };
    "World Monitor" = {
      description = "System monitoring";
      url = "";
      type = "dmg";
    };
  };

  # Create a systemd/launchd service that downloads and installs on activation
  mkAppInstaller = name: app:
    let
      safeName = lib.toLower (builtins.replaceStrings [" "] ["-" ] name);
    in {
      # Create a script that installs the app
      home-manager.users.${config.omanix.user}.home.file.".local/bin/install-${safeName}" = {
        text = ''
          #!/bin/bash
          # Install ${name} (${app.description})
          echo "Installing ${name}..."
          if [ -z "${app.url}" ]; then
            echo "ERROR: No download URL configured for ${name}"
            echo "Set omanix.apps.${safeName}.url in configuration.nix"
            exit 1
          fi
          curl -L -o /tmp/${safeName}.dmg "${app.url}"
          hdiutil attach /tmp/${safeName}.dmg -mountpoint /tmp/${safeName}-mnt -nobrowse -quiet
          cp -R /tmp/${safeName}-mnt/*.app /Applications/ 2>/dev/null || \
            cp -R /tmp/${safeName}-mnt/*/*.app /Applications/ 2>/dev/null
          hdiutil detach /tmp/${safeName}-mnt -quiet
          rm /tmp/${safeName}.dmg
          echo "${name} installed to /Applications/"
        '';
        executable = true;
      };
    };

in {
  options.omanix.apps = {
    # Enable/disable individual apps
    "antigravity-ide".enable = lib.mkEnableOption "Antigravity IDE (Google Agentic IDE)";
    "mkplayer".enable = lib.mkEnableOption "MKPlayer (media player like VLC)";
    "tiny-clips".enable = lib.mkEnableOption "Tiny Clips (video clips)";
    "voicebox".enable = lib.mkEnableOption "Voicebox (voice/audio)";
    "world-monitor".enable = lib.mkEnableOption "World Monitor (system monitoring)";

    # URLs for apps without Homebrew casks
    "antigravity-ide".url = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Download URL for Antigravity IDE .dmg";
    };
    "mkplayer".url = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Download URL for MKPlayer .dmg";
    };
    "tiny-clips".url = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Download URL for Tiny Clips .dmg";
    };
    "voicebox".url = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Download URL for Voicebox .dmg";
    };
    "world-monitor".url = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Download URL for World Monitor .dmg";
    };
  };

  config = lib.mkMerge [
    # Create install scripts for each enabled app
    (lib.mapAttrsToList (name: app:
      let safeName = lib.toLower (builtins.replaceStrings [" "] ["-" ] name);
      in lib.mkIf cfg.${safeName}.enable (mkAppInstaller name app)
    ) apps)
  ];
}
