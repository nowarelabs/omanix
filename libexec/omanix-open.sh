#!/bin/bash
# libexec/omanix-open.sh — open Omanix app
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "open"

usage() {
  cat <<EOF
Usage: omanix open

Open the Omanix Store app.

Examples:
  omanix open
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

log_info "opening Omanix app"
open -a "Omanix" 2>/dev/null || {
  log_error "Omanix app not built"
  echo "Run 'omanix rebuild' first" >&2
  exit 1
}
