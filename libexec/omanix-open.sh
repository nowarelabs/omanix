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

APP_BUNDLE="/Applications/Omanix.app"
log_info "opening Omanix app"
if [[ ! -e "$APP_BUNDLE/Contents/MacOS/Omanix" ]]; then
  log_error "Omanix app not built"
  echo "Run 'omanix rebuild' first" >&2
  exit 1
fi
# -n: force a fresh GUI instance. The omabar/omatiles launchd agents run the
# same bundle, so LaunchServices would otherwise route the open event to that
# CLI-mode process (error -600) instead of launching the Store.
open -n -a "Omanix" 2>/dev/null || {
  log_error "could not open Omanix app"
  exit 1
}
