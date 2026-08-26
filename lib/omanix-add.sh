#!/bin/bash
# lib/omanix-add.sh — add a package declaratively
# Routes: nixpkgs → homebrew cask → error
# Edits configuration.nix, then user runs omanix rebuild
set -e

FLAKE_DIR="${FLAKE_DIR:-$HOME/.config/omanix}"
CONFIG="$FLAKE_DIR/configuration.nix"
NAME="${1:?Usage: omanix add <package>}"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: $CONFIG not found. Is Omanix installed?" >&2
  exit 1
fi

# Check if already installed (match only uncommented lines)
if grep -qE "^[^#]*pkgs\.$NAME\b" "$CONFIG" 2>/dev/null || grep -qE "^[^#]*\"$NAME\"" "$CONFIG" 2>/dev/null; then
  echo "$NAME is already in configuration.nix"
  exit 0
fi

# 1. Try nixpkgs
echo "Searching nixpkgs for $NAME..."
if nix search --json nixpkgs "^${NAME}$" 2>/dev/null | jq -e 'keys | length > 0' > /dev/null 2>&1; then
  echo "Found in nixpkgs — adding to environment.systemPackages"

  if grep -qE "^[^#]*environment\.systemPackages" "$CONFIG"; then
    # Uncommented systemPackages line exists — append to it
    sed -i '' "/^[^#]*environment\.systemPackages/{/pkgs\.$NAME/!s|\]| pkgs.$NAME ]|;}" "$CONFIG"
  else
    # No uncommented line — add one before closing }
    sed -i '' "/^}/i\\
  environment.systemPackages = with pkgs; [ pkgs.$NAME ];\\
" "$CONFIG"
  fi

  echo "Added pkgs.$NAME to configuration.nix"
  echo "Run 'omanix rebuild' to install"
  exit 0
fi

# 2. Try homebrew cask
echo "Searching homebrew for $NAME..."
if brew search --cask "$NAME" 2>/dev/null | grep -q "^${NAME}$"; then
  echo "Found as homebrew cask — adding to homebrew.casks"

  if grep -qE "^[^#]*homebrew\.casks" "$CONFIG"; then
    sed -i '' "/^[^#]*homebrew\.casks/{/\"$NAME\"/!s|\]| \"$NAME\" ]|;}" "$CONFIG"
  else
    sed -i '' "/^}/i\\
  homebrew.casks = [ \"$NAME\" ];\\
" "$CONFIG"
  fi

  echo "Added \"$NAME\" to configuration.nix"
  echo "Run 'omanix rebuild' to install"
  exit 0
fi

# 3. Neither
echo "Error: '$NAME' not found in nixpkgs or homebrew" >&2
echo "To add manually:" >&2
echo "  1. For nixpkgs: add 'pkgs.$NAME' to environment.systemPackages" >&2
echo "  2. For brew: add \"$NAME\" to homebrew.casks" >&2
echo "  3. For custom: add 'inputs.$NAME.url = \"github:...\"' to flake.nix" >&2
exit 1
