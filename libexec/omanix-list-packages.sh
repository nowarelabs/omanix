#!/bin/bash
# libexec/omanix-list-packages.sh — output all declared packages as JSON
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "list-packages"

usage() {
  cat <<EOF
Usage: omanix list-packages

Output all declared packages as JSON (used by Omanix Store).

Examples:
  omanix list-packages
  omanix list-packages | jq '.[] | select(.source == "nixpkgs")'
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_installed
require_command nix "querying packages"
require_command jq "formatting JSON"

header "Packages"

cd "$FLAKE_DIR"
FLAKE_REF=".#darwinConfigurations.$HOST"
TMPDIR_LIST=$(mktemp -d)
export NIX_CONFIG="warn-dirty = false"

log_info "querying nix eval for $HOST"

nix eval --json "$FLAKE_REF.config.environment.systemPackages" \
  --apply 'map (p: { source = "nixpkgs"; name = p.name; description = (p.meta.description or ""); })' \
  > "$TMPDIR_LIST/nixpkgs.json" 2>/dev/null || echo "[]" > "$TMPDIR_LIST/nixpkgs.json"

nix eval --json "$FLAKE_REF.config.homebrew.casks" \
  --apply 'map (c: { source = "homebrew-cask"; name = c.name; description = ""; })' \
  > "$TMPDIR_LIST/casks.json" 2>/dev/null || echo "[]" > "$TMPDIR_LIST/casks.json"

nix eval --json "$FLAKE_REF.config.homebrew.brews" \
  --apply 'map (b: { source = "homebrew-brew"; name = (if builtins.isString b then b else b.name); description = ""; })' \
  > "$TMPDIR_LIST/brews.json" 2>/dev/null || echo "[]" > "$TMPDIR_LIST/brews.json"

nix eval --json "$FLAKE_REF.config.omanix.apps" \
  --apply 'cfg: map (name: { source = "custom"; name = name; description = ""; }) (builtins.filter (name: cfg.${name}.enable) (builtins.attrNames cfg))' \
  > "$TMPDIR_LIST/custom.json" 2>/dev/null || echo "[]" > "$TMPDIR_LIST/custom.json"

jq -s 'add // []' "$TMPDIR_LIST/nixpkgs.json" "$TMPDIR_LIST/casks.json" "$TMPDIR_LIST/brews.json" "$TMPDIR_LIST/custom.json"

rm -rf "$TMPDIR_LIST"
log_info "listed all packages"
