#!/bin/bash
# lib/omanix-add.sh — add a package declaratively
# Routes: nixpkgs → homebrew cask → error
# Edits configuration.nix, then user runs omanix rebuild
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.omanix}"
CONFIG="$FLAKE_DIR/configuration.nix"
NAME="${1:?Usage: omanix add <package>}"

# Source logging
if [[ -f "$FLAKE_DIR/lib/log.sh" ]]; then
  source "$FLAKE_DIR/lib/log.sh"
else
  log_debug() { :; }
  log_info()  { :; }
  log_warn()  { :; }
  log_error() { :; }
fi

if [[ ! -f "$CONFIG" ]]; then
  log_error "add" "$CONFIG not found. Is Omanix installed?"
  echo "Error: $CONFIG not found. Is Omanix installed?" >&2
  exit 1
fi

log_info "add" "checking if $NAME is already installed"

# Check if already installed (match only uncommented lines)
if grep -qE "^[^#]*pkgs\.$NAME\b" "$CONFIG" 2>/dev/null || grep -qE "^[^#]*\"$NAME\"" "$CONFIG" 2>/dev/null; then
  echo "$NAME is already in configuration.nix"
  exit 0
fi

# 1. Try nixpkgs
echo "Searching nixpkgs for $NAME..."
if nix search --json nixpkgs "^${NAME}$" 2>/dev/null | jq -e 'keys | length > 0' > /dev/null 2>&1; then
  log_info "add" "found $NAME in nixpkgs"
  echo "Found in nixpkgs — adding to environment.systemPackages"

  if grep -qE "^[^#]*environment\.systemPackages" "$CONFIG"; then
    # Existing uncommented line — insert package before the closing ]
    # Handle both single-line [... ] and multi-line [...\n]
    if grep -qE "^[^#]*environment\.systemPackages.*\];" "$CONFIG"; then
      # Single-line: pkgs.foo ]; → pkgs.foo pkgs.NAME ];
      sed -i '' "/^[^#]*environment\.systemPackages/s|\];| pkgs.$NAME ]|;" "$CONFIG"
    else
      # Multi-line: insert before the ] line
      sed -i '' "/^\];$/i\\
  pkgs.$NAME
" "$CONFIG"
    fi
  else
    # No existing line — add before closing }
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
  log_info "add" "found $NAME as homebrew cask"
  echo "Found as homebrew cask — adding to homebrew.casks"

  if grep -qE "^[^#]*homebrew\.casks" "$CONFIG"; then
    # Existing uncommented line — insert package before closing ]
    if grep -qE "^[^#]*homebrew\.casks.*\];" "$CONFIG"; then
      # Single-line: [ "foo" ]; → [ "foo" "NAME" ];
      sed -i '' "/^[^#]*homebrew\.casks/s|\];| \"$NAME\" ]|;" "$CONFIG"
    else
      # Multi-line: insert before the ] line
      sed -i '' "/^\];$/i\\
  \"$NAME\"
" "$CONFIG"
    fi
  else
    # No existing line — add before closing }
    sed -i '' "/^}/i\\
  homebrew.casks = [ \"$NAME\" ];\\
" "$CONFIG"
  fi

  echo "Added \"$NAME\" to configuration.nix"
  echo "Run 'omanix rebuild' to install"
  exit 0
fi

# 3. Neither
log_error "add" "$NAME not found in nixpkgs or homebrew"
echo "Error: '$NAME' not found in nixpkgs or homebrew" >&2
echo "To add manually:" >&2
echo "  1. For nixpkgs: add 'pkgs.$NAME' to environment.systemPackages" >&2
echo "  2. For brew: add \"$NAME\" to homebrew.casks" >&2
echo "  3. For custom: add 'inputs.$NAME.url = \"github:...\"' to flake.nix" >&2
exit 1
