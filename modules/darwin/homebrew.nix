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
    brews = []; # not in nixpkgs: <reason>
    casks = []; # not in nixpkgs: <reason>
  };
}
