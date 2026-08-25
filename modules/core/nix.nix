# modules/core/nix.nix — Nix daemon settings (shared mac+linux)
# nix-darwin manages nix-daemon when nix.enable is set.
{ self, pkgs, ... }: {
  nix.enable = true;
  nix.settings.experimental-features = "nix-command flakes";
  nix.package = pkgs.nix;

  system.configurationRevision = self.rev or self.dirtyRev or null;
}
