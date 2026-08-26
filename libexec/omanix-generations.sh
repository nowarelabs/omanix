#!/bin/bash
# libexec/omanix-generations.sh — list previous system generations
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "generations"

usage() {
  cat <<EOF
Usage: omanix generations

List all system generations. Shows generation number, date, and store path.

Examples:
  omanix generations
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_installed
require_sudo
require_command darwin-rebuild "listing generations"

header "Generations"

sudo darwin-rebuild --list-generations
