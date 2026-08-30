{
  description = "Omanix — declarative desktop for Mac (and future Linux)";

  inputs = {
    # The package catalog. Pin a rev, not `nixos-unstable`. Comment where the rev came from.
    nixpkgs.url = "github:NixOS/nixpkgs/917fec990948658ef1ccd07cef2a1ef060786846"; # from config/flake.nix:5, 2026-08

    # The macOS module system. Must follow nixpkgs or overlay skew breaks.
    nix-darwin.url = "github:LnL7/nix-darwin/52d061516108769656a8bd9c6e811c677ec5b462";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # The home module system. Same follows.
    home-manager.url = "github:nix-community/home-manager/27b93804fbef1544cb07718d3f0a451f4c4cd6c0";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager }:
    let
      lib = import ./lib/mkSystem.nix { inherit inputs; };
      # Read hostname from configuration.nix (single source of truth)
      hostname = lib.readHostFromConfig ./configuration.nix;
    in {
      # The host the green user edits in `configuration.nix`:
      darwinConfigurations.${hostname} = lib.mkSystem {
        system = "aarch64-darwin"; # from inventory.json, Apple M1 Pro
        modules = [
          # Core (shared mac+linux)
          ./modules/core/options.nix  # typed omanix.* options (host, user, theme)
          ./modules/core/nix.nix      # nix daemon, experimental features, revision
          ./modules/core/fonts.nix    # shared fonts
          # Theme
          ./modules/theme/options.nix # omanix.theme enum + overrides
          ./modules/theme/theme.nix   # themed distribution -> Ghostty (lib/themed.nix)
          # Desktop (Phase 4: Owin workspaces — AXUI + declarative mappings)
          ./modules/desktop/workspaces.nix
          # Darwin-only
          ./modules/darwin/system.nix # system.defaults (dock, finder, loginwindow)
          ./modules/darwin/pam.nix    # Touch ID, primary user, users.users
          ./modules/darwin/activation.nix # preActivation scripts (postgresql dir)
          ./modules/darwin/home-manager.nix # home-manager integration
          ./modules/darwin/homebrew.nix  # Homebrew (pristine, declarative)
          ./modules/darwin/packages.nix  # system packages
          ./modules/darwin/sudo.nix      # passwordless sudo for darwin-rebuild
          ./modules/darwin/services.nix  # redis, postgresql
          ./modules/darwin/env.nix       # environment variables
          ./modules/darwin/shell.nix     # zsh config, aliases, direnv
          ./modules/darwin/omabar.nix    # Omanix Omabar (menu bar) + Omatiles (tiling), native SwiftUI modules (omanix.omabar.*, omanix.omatiles.*)
          ./modules/darwin/omatiles.nix

          # Apps
          ./modules/apps/gui/options.nix   # Omanix app options
          ./modules/apps/gui/default.nix   # Omanix app (SwiftUI GUI, enabled by default)
          ./modules/apps/custom.nix        # Apps not in Homebrew (Antigravity, MKPlayer, etc.)
          # Services
          ./modules/services/ollama.nix  # Ollama daemon for local AI (opt-in)
          # The file you edit
          ./configuration.nix
          # Host-specific overrides
          ./hosts/my-mac/default.nix
        ];
      };

      # Future: second Mac — same file, different host overlay
      # darwinConfigurations."work-mac" = lib.mkSystem {
      #   system = "x86_64-darwin";
      #   modules = [ ./configuration.nix ./hosts/work-mac/default.nix ];
      # };

      # Future: nixosConfigurations."my-linux" = lib.mkSystem { system = "x86_64-linux"; ... };

      # For `nix develop` and CI
      devShells.aarch64-darwin.default = import ./shell.nix { inherit inputs; };

      checks.aarch64-darwin.default = import ./checks/darwin-check.nix { inherit inputs; };
    };
}
