# modules/core/fonts.nix — shared fonts (mac+linux)
{ pkgs, ... }: {
  fonts.packages = with pkgs; [
    jetbrains-mono-nerd
  ];
}
