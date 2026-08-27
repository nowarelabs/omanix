# Welcome to Omanix — edit host, user, theme, widgets here, then `omanix rebuild`
# See docs/principles.md:3 for why you never edit .toml/.tpl
#
# Available options (all typed, see modules/core/options.nix and modules/theme/options.nix):
#   omanix.host       — machine hostname (`scutil --get LocalHostName`)
#   omanix.user       — primary user (`whoami`)
#   omanix.theme      — bar+terminal+app theme (see `ls themes/`)
#   omanix.bar.*      — bar position, transparency
#   omanix.widgets.*  — toggle widgets (pomodoro, clock, store)
#
# Packages: use `omanix add <name>` (routes nixpkgs → brew) or add below.
# Contributor rule: packages/ is ONLY for Omanix adapters. Before any packages/foo.nix,
# nix search + brew search miss must be pasted in PR description (conventions.md:6).
{ pkgs, ... }: {
  omanix.host = "Vances-MacBook-Pro"; # `scutil --get LocalHostName`
  omanix.user = "vanceworks"; # `whoami` — also system.primaryUser
  omanix.theme = "tokyo-night"; # see `ls themes/` and docs/themes.md (12 themes)
  omanix.bar = {
    position = "top"; # top | bottom — flows around the notch on MacBook Pro
    transparent = false; # true for glass desktop
    # blur = false; # vibrancy blur (best with transparent)
    # blurRadius = 50; # 0-100
    # style = "default"; # default | minimal | glass | modern
    # colorScheme = "auto"; # auto | dark | light
  };
  # omanix.themeOverrides.accent = "#FF00FF"; # per-color override (see docs/themes.md)
  # omanix.themeOverrides.background = "#0a0a12";
  # omanix.widgets.pomodoro.enable = true;
  # omanix.widgets.clock.enable = true;
  # omanix.homebrew.cleanup = "none"; # "uninstall" (default), "zap", or "none"

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
