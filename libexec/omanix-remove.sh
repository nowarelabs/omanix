#!/bin/bash
# libexec/omanix-remove.sh — remove a package declaratively
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "remove"

CONFIG=""

usage() {
  cat <<EOF
Usage: omanix remove <package>

Remove a package from your configuration.
Finds the package in environment.systemPackages or homebrew.casks and removes it.

Examples:
  omanix remove ripgrep
  omanix remove google-chrome
EOF
}

# --- Helpers ---

remove_from_nixpkgs() {
  local name="$1"
  if ! grep -qE "^[^#]*pkgs\.$name\b" "$CONFIG" 2>/dev/null; then
    return 1
  fi

  sed -i '' "/^[^#]*pkgs\.$name\b/d" "$CONFIG"
  sed -i '' '/^\[ \]$/d' "$CONFIG"
  sed -i '' '/^\[$/N;/\n\];$/d' "$CONFIG"

  log_info "removed pkgs.$name from systemPackages"
  echo "Removed pkgs.$name from configuration.nix"
  echo "Run 'omanix rebuild' to uninstall"
  exit 0
}

remove_from_homebrew() {
  local name="$1"
  if ! grep -qE "^[^#]*\"$name\"" "$CONFIG" 2>/dev/null; then
    return 1
  fi

  sed -i '' "/^[^#]*\"$name\"/d" "$CONFIG"
  sed -i '' '/^\[ \]$/d' "$CONFIG"
  sed -i '' '/^\[$/N;/\n\];$/d' "$CONFIG"

  log_info "removed $name from homebrew.casks"
  echo "Removed \"$name\" from configuration.nix"
  echo "Run 'omanix rebuild' to uninstall"
  exit 0
}

# --- Main ---

if [[ -z "${1:-}" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  [[ -z "${1:-}" ]] && exit 1
  exit 0
fi

NAME="$1"

require_installed
CONFIG="$FLAKE_DIR/configuration.nix"
require_file "$CONFIG" "Is Omanix properly installed?"

header "Remove Package: $NAME"

log_info "looking for $NAME in $CONFIG"

remove_from_nixpkgs "$NAME" || remove_from_homebrew "$NAME" || {
  log_error "$NAME not found in configuration.nix (uncommented)"
  echo "Error: '$NAME' not found in configuration.nix (uncommented)" >&2
  exit 1
}
