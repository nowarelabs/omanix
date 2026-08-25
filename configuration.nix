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
  omanix.theme = "tokyo-night"; # see `ls themes/`
  omanix.bar = {
    position = "top"; # flows around the notch on MacBook Pro
    transparent = false;
  };
  # omanix.widgets.pomodoro.enable = true;
  # omanix.widgets.clock.enable = true;
  # environment.systemPackages = with pkgs; [ ripgrep ];
  # homebrew.casks = [ "google-chrome" ];
}
