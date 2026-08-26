#!/bin/bash
# lib/omanix-remove.sh — remove a package declaratively
# Edits configuration.nix, then user runs omanix rebuild
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.config/omanix}"
CONFIG="$FLAKE_DIR/configuration.nix"
NAME="${1:?Usage: omanix remove <package>}"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: $CONFIG not found. Is Omanix installed?" >&2
  exit 1
fi

# Try to remove from environment.systemPackages
# Match only uncommented lines containing pkgs.NAME
if grep -qE "^[^#]*pkgs\.$NAME\b" "$CONFIG" 2>/dev/null; then
  # Remove the package reference (may leave empty list)
  sed -i '' "/^[^#]*pkgs\.$NAME\b/d" "$CONFIG"
  # Clean up empty lists: [ ] or [\n] → []
  sed -i '' '/^\[ \]$/d' "$CONFIG"
  sed -i '' '/^\[$/N;/\n\];$/d' "$CONFIG"
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
  echo "Removed \"$NAME\" from configuration.nix"
  echo "Run 'omanix rebuild' to uninstall"
  exit 0
fi

echo "Error: '$NAME' not found in configuration.nix (uncommented)" >&2
exit 1
