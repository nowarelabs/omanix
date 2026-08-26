#!/bin/bash
# libexec/omanix-version.sh — print version
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "version"

usage() {
  cat <<EOF
Usage: omanix version

Print Omanix version and system info.

Examples:
  omanix version
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

VERSION=$(cat "$FLAKE_DIR/version" 2>/dev/null || echo "dev")

echo "Omanix $VERSION"
echo "nixpkgs: 917fec990948658ef1ccd07cef2a1ef060786846"
