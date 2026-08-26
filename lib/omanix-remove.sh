#!/bin/bash
# lib/omanix-remove.sh — remove a package declaratively
# Edits configuration.nix, then user runs omanix rebuild
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.omanix}"
CONFIG="$FLAKE_DIR/configuration.nix"
NAME="${1:?Usage: omanix remove <package>}"

# Source logging
if [[ -f "$FLAKE_DIR/lib/log.sh" ]]; then
  source "$FLAKE_DIR/lib/log.sh"
fi

if [[ ! -f "$CONFIG" ]]; then
  log_error "remove" "$CONFIG not found. Is Omanix installed?"
  echo "Error: $CONFIG not found. Is Omanix installed?" >&2
  exit 1
fi

log_info "remove" "looking for $NAME in $CONFIG"

# Try to remove from environment.systemPackages
# Match only uncommented lines containing pkgs.NAME
if grep -qE "^[^#]*pkgs\.$NAME\b" "$CONFIG" 2>/dev/null; then
  # Remove the package reference (may leave empty list)
  sed -i '' "/^[^#]*pkgs\.$NAME\b/d" "$CONFIG"
  # Clean up empty lists: [ ] or [\n] → []
  sed -i '' '/^\[ \]$/d' "$CONFIG"
  sed -i '' '/^\[$/N;/\n\];$/d' "$CONFIG"
  log_info "remove" "removed pkgs.$NAME from systemPackages"
  echo "Removed pkgs.$NAME from configuration.nix"
  echo "Run 'omanix rebuild' to uninstall"
  exit 0
fi

# Try to remove from homebrew.casks
# Match only uncommented lines containing "NAME"
if grep -qE "^[^#]*\"$NAME\"" "$CONFIG" 2>/dev/null; then
  sed -i '' "/^[^#]*\"$NAME\"/d" "$CONFIG"
  # Clean up empty lists
  sed -i '' '/^\[ \]$/d' "$CONFIG"
  sed -i '' '/^\[$/N;/\n\];$/d' "$CONFIG"
  log_info "remove" "removed $NAME from homebrew.casks"
  echo "Removed \"$NAME\" from configuration.nix"
  echo "Run 'omanix rebuild' to uninstall"
  exit 0
fi

log_error "remove" "$NAME not found in configuration.nix (uncommented)"
echo "Error: '$NAME' not found in configuration.nix (uncommented)" >&2
exit 1
