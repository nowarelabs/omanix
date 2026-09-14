#!/bin/bash
# libexec/omanix-update.sh — update Omanix to latest or specific version
# Machine-owned files (state.nix, version) are gitignored, so the pull can never
# conflict on them; genuine local edits (e.g. configuration.nix) are handled with
# `--autostash`. Stale state options are pruned after the pull.
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.omanix}"

# Source logging
if [[ -f "$FLAKE_DIR/libexec/log.sh" ]]; then
  source "$FLAKE_DIR/libexec/log.sh"
else
  log_info()  { echo "[info] [$1] $2"; }
  log_error() { echo "[error] [$1] $2" >&2; }
fi

VERSION_FILE="$FLAKE_DIR/version"

usage() {
  cat <<EOF
Usage: omanix update [options]

Options:
  (none)              Update to latest from origin/main
  --version <tag>     Checkout specific version tag (e.g., v1.2.3)
  --commit <sha>      Checkout specific commit hash
  --dry-run           Show what would change without applying
  --no-rebuild        Skip automatic rebuild after update
  -h, --help          Show this help

Examples:
  omanix update                # pull latest
  omanix update --version v1.2.3
  omanix update --commit abc123
  omanix update --dry-run      # preview only
EOF
}

DRY_RUN=false
NO_REBUILD=false
TARGET_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      shift
      TARGET_REF="${1:-}"
      if [[ -z "$TARGET_REF" ]]; then
        log_error "update" "missing version tag"
        exit 1
      fi
      ;;
    --commit)
      shift
      TARGET_REF="${1:-}"
      if [[ -z "$TARGET_REF" ]]; then
        log_error "update" "missing commit hash"
        exit 1
      fi
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --no-rebuild)
      NO_REBUILD=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "update" "unknown option: $1"
      usage >&2
      exit 1
      ;;
  esac
  shift
done

# Ensure we're in a git repo
if [[ ! -d "$FLAKE_DIR/.git" ]]; then
  log_error "update" "$FLAKE_DIR is not a git repository"
  echo "Run 'omanix install' first to clone the repository." >&2
  exit 1
fi

cd "$FLAKE_DIR"

# Get current version
CURRENT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")
echo "Current version: ${CURRENT_TAG:-$CURRENT_SHA}"

# True if any tracked file is still unmerged (UU/AA/...).
git_unresolved() {
  ! git diff --name-only --diff-filter=U --quiet
}

# Fetch latest from remote
echo "Fetching from origin..."
git fetch origin 2>&1

if [[ -n "$TARGET_REF" ]]; then
  # Pin to specific version/commit
  REMOTE_SHA=$(git rev-parse --short "$TARGET_REF" 2>/dev/null || echo "")
  if [[ -z "$REMOTE_SHA" ]]; then
    log_error "update" "ref '$TARGET_REF' not found"
    echo "Available tags:" >&2
    git tag -l | head -10 >&2
    exit 1
  fi

  echo "Target: $TARGET_REF ($REMOTE_SHA)"

  if [[ "$CURRENT_SHA" == "$REMOTE_SHA" ]]; then
    echo "Already at $TARGET_REF"
    exit 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would change: $CURRENT_SHA → $REMOTE_SHA"
    echo "Commits between:"
    git log --oneline "$CURRENT_SHA..$REMOTE_SHA" 2>/dev/null | head -20
    exit 0
  fi

  # Machine-owned state file is gitignored; back it up so a checkout of an older
  # tree (which may still track state.nix) cannot clobber local machine values.
  "$FLAKE_DIR/libexec/omanix-state.sh" ensure_state
  local STATE_BAK
  STATE_BAK="$(mktemp)"
  cp state.nix "$STATE_BAK" 2>/dev/null || true

  # Check for uncommitted changes
  if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
    echo "Stashing local changes..."
    git stash push -m "omanix-update-$(date +%Y%m%d-%H%M%S)"
    STASHED=true
  else
    STASHED=false
  fi

  # Checkout target
  log_info "update" "checking out $TARGET_REF"
  git checkout "$TARGET_REF" 2>&1

  # Restore machine-owned state, then prune against the target's schema.
  cp "$STATE_BAK" state.nix 2>/dev/null || true
  rm -f "$STATE_BAK"
  "$FLAKE_DIR/libexec/omanix-state.sh" prune >/dev/null 2>&1 || true

  # Pop stash if we stashed
  if [[ "$STASHED" == "true" ]]; then
    echo "Restoring local changes..."
    if ! git stash pop 2>&1; then
      log_error "update" "conflict while restoring local changes"
      echo "Your changes are in 'git stash list'. Resolve manually:" >&2
      echo "  cd ~/.omanix && git stash pop" >&2
      exit 1
    fi
  fi

  if git_unresolved; then
    log_error "update" "unresolved conflicts after checkout"
    echo "Aborting before rebuild. Resolve manually, then re-run 'omanix update'." >&2
    exit 1
  fi
else
  # Update to latest from origin/main
  LOCAL_SHA=$(git rev-parse HEAD)
  REMOTE_SHA=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null || echo "")

  if [[ -z "$REMOTE_SHA" ]]; then
    log_error "update" "could not determine remote HEAD"
    exit 1
  fi

  if [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
    echo "Already up to date ($CURRENT_SHA)"
    exit 0
  fi

  BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
  AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "?")
  echo "Behind by $BEHIND commits, ahead by $AHEAD commits"
  echo ""
  echo "New commits:"
  git log --oneline HEAD..origin/main 2>/dev/null | head -20

  if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "Dry run — no changes made"
    exit 0
  fi

  # Machine-owned files (state.nix, version) are gitignored, so they are never
  # stashed or merged — a pull can no longer conflict on them. --autostash covers
  # any genuine local edits (e.g. configuration.nix) and restores them on success.
  "$FLAKE_DIR/libexec/omanix-state.sh" ensure_state

  # Pull with rebase
  log_info "update" "pulling latest from origin/main"
  if ! git pull --rebase --autostash origin main 2>&1; then
    log_error "update" "pull failed (conflicts)"
    echo "Resolve conflicts manually, then run 'omanix update' again:" >&2
    echo "  cd ~/.omanix && git status" >&2
    echo "  (git rebase --continue   or: git rebase --abort)" >&2
    exit 1
  fi

  # Drop stale option keys (e.g. the omabar -> spacebar rename) from the rewritten
  # upstream so the rebuild can never trip on options that no longer exist.
  if ! "$FLAKE_DIR/libexec/omanix-state.sh" prune >/dev/null 2>&1; then
    log_warn "update" "state prune failed; continuing"
  fi

  if git_unresolved; then
    log_error "update" "unresolved conflicts after pull"
    echo "Aborting before rebuild. Resolve manually, then re-run 'omanix update'." >&2
    exit 1
  fi
fi

# Update version file
NEW_SHA=$(git rev-parse --short HEAD)
NEW_TAG=$(git describe --tags --exact-match 2>/dev/null || echo "")
echo "${NEW_TAG:-$NEW_SHA}" > "$VERSION_FILE"
echo ""
echo "Updated: $CURRENT_SHA → ${NEW_TAG:-$NEW_SHA}"

# Auto-rebuild unless skipped
if [[ "$NO_REBUILD" == "true" ]]; then
  echo "Rebuild skipped (--no-rebuild)"
  echo "Run 'omanix rebuild' to apply changes"
else
  echo ""
  echo "Rebuilding system..."
  omanix rebuild
fi
