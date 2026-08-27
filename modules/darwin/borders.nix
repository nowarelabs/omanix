# modules/darwin/borders.nix — JankyBorders (window borders that pop) — Omanix Omakase
# Theme-aware, rounded, accent on focused window. Complements AeroSpace tiling.
# See frankcarv.com/blog/sketchy, goodies#highlight-focused-windows, mozumasu window customization
# Installed via Homebrew (FelixKratz/formulae/borders) — Declarative, pristine
{ config, lib, pkgs, ... }:
{
  options.omanix.borders = {
    width = lib.mkOption {
      type = lib.types.numbers.between 1.0 10.0;
      default = 5.0;
      description = "JankyBorders active border width (1.0-10.0). Omanix Omakase default 5.0 like frankcarv.";
      example = 4.0;
    };
    radius = lib.mkOption {
      type = lib.types.numbers.between 0 20;
      default = 12;
      description = "Corner radius for borders (matches OC.cardCorner 12).";
      example = 8;
    };
    style = lib.mkOption {
      type = lib.types.enum [ "round" "square" ];
      default = "round";
      description = "Border style: round (macOS corners) or square.";
      example = "square";
    };
  };

  config = let
    themed = import ../../lib/themed.nix { inherit lib; };
    colors = themed.getThemeColors config;
    user = config.omanix.user;
    borderColors = themed.getAppColors config "borders";
    toARGB = hex: alpha: "0x${alpha}${lib.removePrefix "#" hex}";
    activeColor = toARGB (borderColors.accent or colors.accent) "ff";
    inactiveColor = toARGB (borderColors.muted or colors.muted) "40";
    borderWidth = toString config.omanix.borders.width;
    borderRadius = toString config.omanix.borders.radius;
    borderStyle = config.omanix.borders.style;
  in {
  # Ensure Homebrew tap/brew for borders (pristine, declarative)
  homebrew.taps = lib.mkAfter [ "FelixKratz/formulae" ];
  homebrew.brews = lib.mkAfter [ "borders" ];

  # Write bordersrc — sourced by `borders` on launch (chmod +x)
  home-manager.users.${user} = lib.mkIf (user != "") {
    xdg.configFile."borders/bordersrc" = {
      executable = true;
      text = ''
        #!/bin/bash
        # Omanix JankyBorders — generated via lib/themed.nix + omanix.borders
        # Theme: ${config.omanix.theme} | active ${activeColor} inactive ${inactiveColor}
        # Do not edit — set omanix.theme / omanix.borders.* in configuration.nix or Store
        options=(
          style=${borderStyle}
          width=${borderWidth}
          hidpi=on
          active_color=${activeColor}
          inactive_color=${inactiveColor}
        )
        # Round matches OC.cardCorner; hidpi ensures crisp on Retina
        borders "''${options[@]}"
      '';
    };
  };

  # AeroSpace after-startup hook ensures borders starts with AeroSpace (goodies#3)
  # Also launchd fallback for pristine guarantee
  launchd.user.agents.omanix-borders = lib.mkIf (user != "") {
    serviceConfig = {
      Label = "org.omanix.borders";
      ProgramArguments = [
        "/opt/homebrew/bin/borders"
        "active_color=${activeColor}"
        "inactive_color=${inactiveColor}"
        "width=${borderWidth}"
        "style=${borderStyle}"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "/tmp/omanix-borders.log";
      StandardErrorPath = "/tmp/omanix-borders.log";
    };
  };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      # JankyBorders: ensure service is running with theme colors
      if command -v borders >/dev/null 2>&1 || command -v /opt/homebrew/bin/borders >/dev/null 2>&1; then
        BORDERS_BIN=$(command -v borders 2>/dev/null || echo "/opt/homebrew/bin/borders")
        pkill -f "borders active_color" 2>/dev/null || true
        "$BORDERS_BIN" active_color=${activeColor} inactive_color=${inactiveColor} width=${borderWidth} style=${borderStyle} 2>/dev/null &
        echo "JankyBorders started: active ${activeColor} inactive ${inactiveColor} width ${borderWidth}"
      else
        echo "JankyBorders not yet installed — will be available after 'brew install borders' + rebuild"
      fi
    '';
  };
}
