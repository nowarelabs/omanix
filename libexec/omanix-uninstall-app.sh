#!/bin/bash
# libexec/omanix-uninstall-app.sh — uninstall a custom app
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "uninstall-app"

usage() {
  cat <<EOF
Usage: omanix uninstall-app <name>

Uninstall a custom app.

Examples:
  omanix uninstall-app mkplayer
EOF
}

if [[ -z "${1:-}" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  [[ -z "${1:-}" ]] && exit 1
  exit 0
fi

APP_NAME="$1"
SCRIPT="$HOME/.local/bin/uninstall-$APP_NAME"

require_installed
require_file "$SCRIPT" "No uninstall script found for $APP_NAME"

header "Uninstall App: $APP_NAME"

log_info "running $SCRIPT"
"$SCRIPT"
log_info "uninstalled $APP_NAME"

summary "Uninstall complete."
