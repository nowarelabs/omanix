# modules/core/fonts.nix — shared fonts (mac+linux)
{ pkgs, ... }: {
  fonts.packages = with pkgs; [
    # Phase 03 will add more fonts from omarchy-mac vendored set
    # jetbrains-mono-nerd
  ];
}
