# modules/darwin/homebrew.nix — Homebrew (pristine, declarative)
# Only for signed GUI .app casks not in nixpkgs (see principles.md:4)
{ config, ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      upgrade = true;
      cleanup = config.omanix.homebrew.cleanup;
    };
    taps = [ "anomalyco/tap" ];
    brews = [
      "amber"
      "ffmpeg"
      "opencode"
      "portaudio"
      "ripgrep"
      "ta-lib"
    ];
    casks = [
      "caffeine"
      "chromium"
      "github"
      "google-chrome"
      "mongodb-compass"
      "orbstack"
      "postico"
      "postman"
      "slack"
      "sublime-text"
      "visual-studio-code"
      "zoom"

      # Dev tools
      # "android-studio" — IDE for Android development
      # "intellij-idea" — JetBrains IDE

      # AI
      # "ollama"
      # "claude"

      # Communication
      # "whatsapp"

      # System
      # "cloudflare-warp" — VPN
      # "obs" — screen recording/streaming

      # Emulators
      # "bluestacks" — Android emulator

      # Media
      # "mkplayer" — media player (like VLC)

      # Utilities
      # "screendrop" — screenshot tool
      # "wps-office" — office suite
      # "utorrent-web" — torrent client
    ];
    masApps = {
      # amphetamine = 937984704;
    };
  };
}
