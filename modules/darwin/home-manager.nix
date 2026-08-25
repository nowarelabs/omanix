# modules/darwin/home-manager.nix — home-manager integration (darwin-only)
{ config, ... }: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  programs.zsh.enable = true;
}
