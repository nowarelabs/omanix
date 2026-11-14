# modules/darwin/homebrew.nix — Homebrew (pristine, declarative)
# Only for signed GUI .app casks not in nixpkgs (see principles.md:4)
{ config, lib, ... }: {
  homebrew = {
    enable = true;
    onActivation = {
      upgrade = true;
      # Homebrew Bundle disabled `--cleanup` (now requires `--force-cleanup`).
      # Disable nix-darwin's legacy `--cleanup` emission by setting cleanup = "none"
      # and forwarding the modern flags via extraFlags.
      cleanup = "none";
      extraFlags =
        lib.optional (config.omanix.homebrew.cleanup == "uninstall") "--force-cleanup"
        ++ lib.optionals (config.omanix.homebrew.cleanup == "zap") [ "--zap" "--force-cleanup" ];
    };
    taps = [ ];
    brews = [
      "portaudio"
      "ripgrep"
      "ta-lib"
    ];
    casks = [
      "caffeine"
      "orbstack"
    ];
    masApps = {
      # amphetamine = 937984704;
    };
  };
}
