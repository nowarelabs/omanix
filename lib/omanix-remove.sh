#!/bin/bash
# lib/omanix-remove.sh — remove a package declaratively
# Edits configuration.nix, runs nix flake check dry, then rebuilds
set -e

FLAKE_DIR="${FLAKE_DIR:-$HOME/.config/omanix}"
CONFIG="$FLAKE_DIR/configuration.nix"
NAME="${1:?Usage: omanix remove <package>}"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: $CONFIG not found. Is Omanix installed?" >&2
  exit 1
fi

# Try to remove from environment.systemPackages
if grep -q "pkgs\.$NAME" "$CONFIG" 2>/dev/null; then
  sed -i '' "/pkgs\.$NAME/d" "$CONFIG"
  echo "Removed pkgs.$NAME from configuration.nix"
  echo "Run 'omanix rebuild' to uninstall"
  exit 0
fi

# Try to remove from homebrew.casks
if grep -q "\"$NAME\"" "$CONFIG" 2>/dev/null; then
  sed -i '' "/\"$NAME\"/d" "$CONFIG"
  echo "Removed \"$NAME\" from configuration.nix"
  echo "Run 'omanix rebuild' to uninstall"
  exit 0
fi

echo "Error: '$NAME' not found in configuration.nix" >&2
exit 1
