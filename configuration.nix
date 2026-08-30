# Welcome to Omanix — edit host, user, theme, widgets here, then `omanix rebuild`
# See docs/principles.md:3 for why you never edit .toml/.tpl
#
# Available options (all typed, see modules/core/options.nix and modules/theme/options.nix):
#   omanix.host                 — machine hostname (`scutil --get LocalHostName`)
#   omanix.user                 — primary user (`whoami`)
#   omanix.theme                — terminal+app theme (see `ls themes/` and `omanix theme list`)
#   omanix.omabar.*             — status items inside the NATIVE menu bar (Omabar): enable, showClock/Battery/Volume/Wifi/Apps
#   omanix.omatiles.*           — macOS Sequoia window tiling (Omatiles): enable, bindings, enableEdgeDrag/KeyboardShortcuts/Margins
#   omanix.themeOverrides.*     — global per-color overrides (accent, background, etc.)
#   omanix.perApp.*             — per-application overrides (ghostty) — alias theme.perApp.*
#   Use Store GUI (Super → Omanix Store → Themes) or `omanix theme set <name>` + `omanix rebuild`
#
# Packages: use `omanix add <name>` (routes nixpkgs → brew) or add below.
# Contributor rule: packages/ is ONLY for Omanix adapters. Before any packages/foo.nix,
# nix search + brew search miss must be pasted in PR description (conventions.md:6).
{ pkgs, ... }: {
  # Machine-produced option values (written by the Omanix GUI / `omanix state set`).
  # This file is generated and validated — the app never hand-edits this config directly.
  imports = [ ./state.nix ];

  omanix.host = "Vances-MacBook-Pro"; # `scutil --get LocalHostName`
  omanix.user = "vanceworks"; # `whoami` — also system.primaryUser
  omanix.theme = "omanix"; # signature Omakase light — see `ls themes/` and docs/themes.md (13 themes: omanix + 12)
  # omanix.themeOverrides.accent = "#FF00FF"; # global per-color override (see docs/themes.md)
  # omanix.themeOverrides.background = "#0a0a12";
  # Per-app overrides — e.g. terminal darker than UI (Nix path is omanix.perApp due to theme being a string enum):
  # omanix.perApp.ghostty.background = "#000000"; # spec alias omanix.theme.perApp.ghostty.background

  # Custom apps (not in Homebrew) — set URL to install
  # omanix.apps.antigravity-ide.enable = true;
  # omanix.apps.antigravity-ide.url = "https://example.com/antigravity.dmg";
  # omanix.apps.mkplayer.enable = true;
  # omanix.apps.tiny-clips.enable = true;
  # omanix.apps.voicebox.enable = true;
  # omanix.apps.world-monitor.enable = true;

  # Packages: use `omanix add <name>` or add below.
  # environment.systemPackages = with pkgs; [ ripgrep ];
  # homebrew.casks = [ "google-chrome" ];
}
