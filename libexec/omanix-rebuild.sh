#!/bin/bash
# libexec/omanix-rebuild.sh — rebuild system (darwin-rebuild switch)
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "rebuild"

ROLLBACK=false
PREVIEW=false

usage() {
  cat <<EOF
Usage: omanix rebuild [options]

Options:
  (none)              Rebuild system (darwin-rebuild switch)
  --rollback          Undo last build (restore previous generation)
  --preview           Build impure overlay preview (no generation)
  -h, --help          Show this help

Examples:
  omanix rebuild              # apply changes
  omanix rebuild --rollback   # undo last build
  omanix rebuild --preview    # preview theme/widget changes
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rollback) ROLLBACK=true ;;
    --preview)  PREVIEW=true ;;
    -h|--help)  usage; exit 0 ;;
    *)          log_error "unknown option: $1"; usage >&2; exit 1 ;;
  esac
  shift
done

require_installed
require_sudo

header "Rebuild"

if [[ "$ROLLBACK" == "true" ]]; then
  step 1 "Rolling back to previous generation"
  sudo darwin-rebuild --rollback
  log_info "rollback complete"

elif [[ "$PREVIEW" == "true" ]]; then
  step 1 "Building impure overlay preview"
  sudo darwin-rebuild switch --flake "$FLAKE_DIR#$HOST" --impure --show-trace
  log_info "preview build complete"

else
  step 1 "Switching to flake $FLAKE_DIR#$HOST"
  sudo darwin-rebuild switch --flake "$FLAKE_DIR#$HOST" --show-trace
  log_info "switch complete"
fi

summary "Rebuild complete."
