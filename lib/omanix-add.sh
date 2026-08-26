#!/bin/bash
# lib/omanix-add.sh — add a package declaratively
# Routes: nixpkgs → homebrew cask → error
# Edits configuration.nix, runs nix flake check dry, then rebuilds
set -e

FLAKE_DIR="${FLAKE_DIR:-$HOME/.config/omanix}"
CONFIG="$FLAKE_DIR/configuration.nix"
NAME="${1:?Usage: omanix add <package>}"

if [[ ! -f "$CONFIG" ]]; then
  echo "Error: $CONFIG not found. Is Omanix installed?" >&2
  exit 1
fi

# Check if already installed
if grep -q "pkgs\.$NAME\b" "$CONFIG" 2>/dev/null || grep -q "\"$NAME\"" "$CONFIG" 2>/dev/null; then
  echo "$NAME is already in configuration.nix"
  exit 0
fi

# 1. Try nixpkgs
echo "Searching nixpkgs for $NAME..."
if nix search --json nixpkgs "^${NAME}$" 2>/dev/null | jq -e 'keys | length > 0' > /dev/null 2>&1; then
  echo "Found in nixpkgs — adding to environment.systemPackages"
  # Insert into environment.systemPackages
  if grep -q "environment.systemPackages" "$CONFIG"; then
    # Add to existing list
    sed -i '' "s|environment.systemPackages = with pkgs; \[|environment.systemPackages = with pkgs; [ pkgs.$NAME|" "$CONFIG"
  else
    # Add new section
    sed -i '' "/^}/i\\
  environment.systemPackages = with pkgs; [ pkgs.$NAME ];\
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
  if grep -q "homebrew.casks" "$CONFIG"; then
    sed -i '' "s|homebrew.casks = \[|homebrew.casks = [ \"$NAME\"|" "$CONFIG"
  else
    sed -i '' "/^}/i\\
  homebrew.casks = [ \"$NAME\" ];\
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
