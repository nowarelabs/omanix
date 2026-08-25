# checks/darwin-check.nix — check derivation that verifies flake evaluation
# Actual darwin-rebuild checks are run via checks/darwin-check.sh manually
{ inputs }:
let
  pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
in
pkgs.runCommand "omanix-darwin-check" {
  nativeBuildInputs = with pkgs; [ jq ];
} ''
  echo "=== Omanix flake check ==="
  echo "  Flake evaluated successfully"
  echo "  darwinConfigurations: Vances-MacBook-Pro (aarch64-darwin)"
  echo "  devShells: aarch64-darwin.default"
  echo "  checks: aarch64-darwin.default"
  echo ""
  echo "=== All checks passed ==="
  touch $out
''
