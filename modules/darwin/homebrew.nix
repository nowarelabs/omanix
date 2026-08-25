# modules/darwin/homebrew.nix — Homebrew (pristine, declarative)
# Only for signed GUI .app casks not in nixpkgs (see principles.md:4)
{ ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      upgrade = true;
      cleanup = "uninstall"; # pristine: remove casks we added
    };
    taps = [ "anomalyco/tap" ];
    brews = [
      "ta-lib"
      "ffmpeg"
      "portaudio"
      "ripgrep"
      "opencode"
    ];
    casks = [
      "google-chrome"
      "visual-studio-code"
      "slack"
      "caffeine"
      "postico"
      "github"
      "postman"
      "microsoft-teams"
      "zoom"
      "orbstack"
      "wkhtmltopdf"
      "chromium"
      "sublime-text"
      "mongodb-compass"
      "intellij-idea"
    ];
    masApps = {
      # amphetamine = 937984704;
    };
  };
}
