#!/bin/bash
# libexec/omanix-add.sh — add a package declaratively
# Routes: nixpkgs → homebrew cask → error
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "add"

CONFIG=""

usage() {
  cat <<EOF
Usage: omanix add <package>

Add a package to your configuration. Routes automatically:
  1. nixpkgs — added to environment.systemPackages
  2. homebrew cask — added to homebrew.casks
  3. not found — shows manual instructions

Examples:
  omanix add ripgrep
  omanix add google-chrome
  omanix add firefox
EOF
}

# --- Helpers ---

check_already_installed() {
  local name="$1"
  if grep -qE "^[^#]*pkgs\.$name\b" "$CONFIG" 2>/dev/null || grep -qE "^[^#]*\"$name\"" "$CONFIG" 2>/dev/null; then
    log_info "$name is already in configuration.nix"
    echo "$name is already in configuration.nix"
    exit 0
  fi
}

add_to_nixpkgs() {
  local name="$1"
  log_info "searching nixpkgs for $name"
  echo "Searching nixpkgs for $name..."

  if ! nix search --json nixpkgs "^${name}$" 2>/dev/null | jq -e 'keys | length > 0' > /dev/null 2>&1; then
    return 1
  fi

  log_info "found $name in nixpkgs"
  echo "Found in nixpkgs — adding to environment.systemPackages"

  if grep -qE "^[^#]*environment\.systemPackages" "$CONFIG"; then
    if grep -qE "^[^#]*environment\.systemPackages.*\];" "$CONFIG"; then
      sed -i '' "/^[^#]*environment\.systemPackages/s|\];| pkgs.$name ]|;" "$CONFIG"
    else
      sed -i '' "/^\];$/i\\
  pkgs.$name
" "$CONFIG"
    fi
  else
    sed -i '' "/^}/i\\
  environment.systemPackages = with pkgs; [ pkgs.$name ];\\
" "$CONFIG"
  fi

  log_info "added pkgs.$name to systemPackages"
  echo "Added pkgs.$name to configuration.nix"
  echo "Run 'omanix rebuild' to install"
  exit 0
}

add_to_homebrew() {
  local name="$1"
  log_info "searching homebrew for $name"
  echo "Searching homebrew for $name..."

  if ! brew search --cask "$name" 2>/dev/null | grep -q "^${name}$"; then
    return 1
  fi

  log_info "found $name as homebrew cask"
  echo "Found as homebrew cask — adding to homebrew.casks"

  if grep -qE "^[^#]*homebrew\.casks" "$CONFIG"; then
    if grep -qE "^[^#]*homebrew\.casks.*\];" "$CONFIG"; then
      sed -i '' "/^[^#]*homebrew\.casks/s|\];| \"$name\" ]|;" "$CONFIG"
    else
      sed -i '' "/^\];$/i\\
  \"$name\"
" "$CONFIG"
    fi
  else
    sed -i '' "/^}/i\\
  homebrew.casks = [ \"$name\" ];\\
" "$CONFIG"
  fi

  log_info "added $name to homebrew.casks"
  echo "Added \"$name\" to configuration.nix"
  echo "Run 'omanix rebuild' to install"
  exit 0
}

show_not_found() {
  local name="$1"
  log_error "$name not found in nixpkgs or homebrew"
  echo "Error: '$name' not found in nixpkgs or homebrew" >&2
  echo "To add manually:" >&2
  echo "  1. For nixpkgs: add 'pkgs.$name' to environment.systemPackages" >&2
  echo "  2. For brew: add \"$name\" to homebrew.casks" >&2
  echo "  3. For custom: add 'inputs.$name.url = \"github:...\"' to flake.nix" >&2
  exit 1
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

header "Add Package: $NAME"

check_already_installed "$NAME"

# Try nixpkgs, then homebrew, then fail
add_to_nixpkgs "$NAME" || add_to_homebrew "$NAME" || show_not_found "$NAME"
