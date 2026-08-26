#!/bin/bash
# libexec/omanix-upgrade.sh — update flake inputs (nix flake update + rebuild)
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "upgrade"

NO_REBUILD=false

usage() {
  cat <<EOF
Usage: omanix upgrade [options]

Options:
  --no-rebuild    Update flake inputs but skip rebuild
  -h, --help      Show this help

Examples:
  omanix upgrade              # update inputs + rebuild
  omanix upgrade --no-rebuild # update inputs only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-rebuild) NO_REBUILD=true ;;
    -h|--help)    usage; exit 0 ;;
    *)            log_error "unknown option: $1"; usage >&2; exit 1 ;;
  esac
  shift
done

require_installed
require_command nix "updating flake inputs"
require_sudo

header "Upgrade"

step 1 "Updating flake inputs"
nix flake update "$FLAKE_DIR"
log_info "flake inputs updated"

if [[ "$NO_REBUILD" == "true" ]]; then
  log_info "skipping rebuild (--no-rebuild)"
  echo "Rebuild skipped. Run 'omanix rebuild' to apply changes"
else
  step 2 "Rebuilding system"
  "$FLAKE_DIR/bin/omanix" rebuild
fi

summary "Upgrade complete."
