# Welcome to Omanix — edit host, user, theme, widgets here, then `omanix rebuild`
# See docs/principles.md:3 for why you never edit .toml/.tpl
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
