#!/bin/bash
# libexec/omanix-install-app.sh — install a custom app
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "install-app"

usage() {
  cat <<EOF
Usage: omanix install-app <name>

Install a custom app (downloads .dmg, installs to /Applications).

Available apps:
  antigravity-ide, mkplayer, tiny-clips, voicebox, world-monitor

Examples:
  omanix install-app mkplayer
EOF
}

if [[ -z "${1:-}" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  [[ -z "${1:-}" ]] && exit 1
  exit 0
fi

APP_NAME="$1"
SCRIPT="$HOME/.local/bin/install-$APP_NAME"

require_installed
require_file "$SCRIPT" "Make sure omanix.apps.$APP_NAME.enable = true in configuration.nix and rebuild"

header "Install App: $APP_NAME"

log_info "running $SCRIPT"
"$SCRIPT"
log_info "installed $APP_NAME"

summary "Install complete."
