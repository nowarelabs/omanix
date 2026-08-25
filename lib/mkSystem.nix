# lib/mkSystem.nix — the only branching point. ~20 lines.
# If Darwin → darwinSystem. If Linux → nixosSystem. Same `omanix.*` options on both.
{ inputs }: {
  mkSystem = { system, modules }:
    let
      isDarwin = builtins.match ".*-darwin" system != null;
      # Pass self (the flake) to modules via specialArgs
      self = inputs.self or null;
    in
      if isDarwin
      then inputs.nix-darwin.lib.darwinSystem {
        inherit system;
        modules = modules ++ [ inputs.home-manager.darwinModules.home-manager ];
        specialArgs = { inherit self; };
      }
      else inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules;
        specialArgs = { inherit self; };
      };
}
