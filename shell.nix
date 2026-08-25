# shell.nix — dev shell with linters for agents and contributors
{ inputs }:
let
  pkgs = inputs.nixpkgs.legacyPackages.aarch64-darwin;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    statix
    nixfmt-rfc-style
    nixd
    jq
  ];

  shellHook = ''
    echo "Omanix dev shell — statix, nixfmt, nixd in PATH"
    echo "  nix fmt          # format all .nix files"
    echo "  statix check .   # lint for unused bindings"
    echo "  nix flake check  # eval all hosts"
  '';
}
