#!/bin/bash
# libexec/omanix-search.sh — search nixpkgs + homebrew
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "search"

usage() {
  cat <<EOF
Usage: omanix search <package>

Search for packages in nixpkgs and Homebrew.

Examples:
  omanix search ripgrep
  omanix search google-chrome
  omanix search firefox
EOF
}

if [[ -z "${1:-}" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  [[ -z "${1:-}" ]] && exit 1
  exit 0
fi

QUERY="$1"

header "Search: $QUERY"

require_command nix "searching nixpkgs"
require_command brew "searching homebrew"

log_info "searching for $QUERY"

echo "=== nixpkgs ==="
nix search nixpkgs "$QUERY" 2>/dev/null || echo "(no results)"
echo ""

echo "=== homebrew ==="
brew search "$QUERY" 2>/dev/null || echo "(brew not available)"
brew search --cask "$QUERY" 2>/dev/null || true
