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

# state.nix is a machine-owned, tracked file. Bootstrap it if missing and drop
# any stale option keys from a previous release so a rename can never fail the build.
"$FLAKE_DIR/libexec/omanix-state.sh" ensure >/dev/null 2>&1 || log_warn "rebuild" "unable to bootstrap state.nix"
"$FLAKE_DIR/libexec/omanix-state.sh" prune >/dev/null 2>&1 || log_warn "rebuild" "state prune failed"

# Nix flakes copy ONLY git-tracked files into the build source. overlays/ is
# deliberately gitignored (throwaway AI previews), so an overlay would be invisible
# to every build unless staged. Stage it for this eval, then unstage afterwards so
# the gitignored/throwaway semantics stay intact.
stage_overlays() {
  if [[ -d "$FLAKE_DIR/overlays" ]] && [[ -n "$(ls -A "$FLAKE_DIR/overlays" 2>/dev/null)" ]]; then
    git -C "$FLAKE_DIR" add -f overlays
    log_info "overlays staged for this build (gitignored files only reach the flake source when staged)"
  fi
  trap unstage_overlays EXIT
}
unstage_overlays() {
  git -C "$FLAKE_DIR" restore --staged overlays 2>/dev/null || true
}

if [[ "$ROLLBACK" == "true" ]]; then
  step 1 "Rolling back to previous generation"
  sudo darwin-rebuild --rollback
  log_info "rollback complete"

elif [[ "$PREVIEW" == "true" ]]; then
  stage_overlays
  step 1 "Building impure overlay preview"
  sudo darwin-rebuild switch --flake "$FLAKE_DIR#$HOST" --impure --show-trace
  log_info "preview build complete"

else
  stage_overlays
  step 1 "Switching to flake $FLAKE_DIR#$HOST"
  sudo darwin-rebuild switch --flake "$FLAKE_DIR#$HOST" --show-trace
  log_info "switch complete"
fi

summary "Rebuild complete."
