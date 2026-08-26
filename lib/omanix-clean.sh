#!/bin/bash
# lib/omanix-clean.sh — nix garbage collection and house cleaning
# Conservative by default: only deletes old generations
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.omanix}"

# Source logging
if [[ -f "$FLAKE_DIR/lib/log.sh" ]]; then
  source "$FLAKE_DIR/lib/log.sh"
else
  log_info()  { echo "[info] [$1] $2"; }
  log_error() { echo "[error] [$1] $2" >&2; }
fi

# Default settings (overridden by omanix.keepGenerations in configuration.nix)
KEEP_GENERATIONS="${OMANIX_KEEP_GENERATIONS:-5}"
DRY_RUN=false
AGGRESSIVE=false
STORE_GC=false
OPTIMISE=false

usage() {
  cat <<EOF
Usage: omanix clean [options]

Options:
  (none)              Conservative: delete old generations (keeps last $KEEP_GENERATIONS)
  --aggressive        Delete old generations + garbage collect store
  --store-gc          Run nix store gc only
  --optimise          Optimise nix store (hardlink identical files)
  --keep <n>          Number of generations to keep (default: $KEEP_GENERATIONS)
  --dry-run           Show what would be deleted without deleting
  -h, --help          Show this help

Examples:
  omanix clean                # delete old generations (safe)
  omanix clean --dry-run      # preview what would be deleted
  omanix clean --aggressive   # thorough cleaning
  omanix clean --keep 3       # keep only 3 generations
  omanix clean --optimise     # optimise store disk usage
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aggressive)
      AGGRESSIVE=true
      ;;
    --store-gc)
      STORE_GC=true
      ;;
    --optimise)
      OPTIMISE=true
      ;;
    --keep)
      shift
      KEEP_GENERATIONS="${1:-5}"
      if ! [[ "$KEEP_GENERATIONS" =~ ^[0-9]+$ ]]; then
        log_error "clean" "keep must be a number"
        exit 1
      fi
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "clean" "unknown option: $1"
      usage >&2
      exit 1
      ;;
  esac
  shift
done

echo "Omanix Clean"
echo "============"
echo ""

# 1. Show current state
echo "Current state:"
echo "  Generations: $(sudo darwin-rebuild --list-generations 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")"
echo "  Store size: $(du -sh /nix/store 2>/dev/null | cut -f1 || echo "unknown")"
echo "  Log files: $(du -sh "$FLAKE_DIR/logs" 2>/dev/null | cut -f1 || echo "0")"
echo ""

# 2. Delete old generations
echo "Cleaning old generations (keeping last $KEEP_GENERATIONS)..."
if [[ "$DRY_RUN" == "true" ]]; then
  echo "  [dry-run] Would delete generations older than the last $KEEP_GENERATIONS"
  sudo darwin-rebuild --list-generations 2>/dev/null | tail -n +2 | head -n -$KEEP_GENERATIONS || true
else
  # Get all generation numbers
  GENERATIONS=$(sudo darwin-rebuild --list-generations 2>/dev/null | awk 'NR>1 {print $1}')
  TOTAL=$(echo "$GENERATIONS" | wc -l | tr -d ' ')

  if [[ "$TOTAL" -le "$KEEP_GENERATIONS" ]]; then
    echo "  Only $TOTAL generations exist — nothing to delete"
  else
    TO_DELETE=$((TOTAL - KEEP_GENERATIONS))
    echo "  Deleting $TO_DELETE old generation(s)..."
    # Delete oldest generations
    echo "$GENERATIONS" | head -n "$TO_DELETE" | while read -r GEN; do
      if [[ -n "$GEN" ]]; then
        echo "  Removing generation $GEN"
        sudo nix-env --delete-generations "$GEN" 2>/dev/null || true
      fi
    done
    echo "  Kept last $KEEP_GENERATIONS generations"
  fi
fi
echo ""

# 3. Aggressive: garbage collect store
if [[ "$AGGRESSIVE" == "true" || "$STORE_GC" == "true" ]]; then
  echo "Garbage collecting nix store..."
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would run nix store gc"
  else
    nix store gc 2>/dev/null || nix-collect-garbage 2>/dev/null || true
    echo "  Store garbage collected"
  fi
  echo ""
fi

# 4. Optimise store
if [[ "$OPTIMISE" == "true" ]]; then
  echo "Optimising nix store (hardlinking identical files)..."
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would run nix store optimise"
  else
    nix store optimise 2>/dev/null || true
    echo "  Store optimised"
  fi
  echo ""
fi

# 5. Clean old log files
echo "Cleaning old log files (keeping last 30 days)..."
LOG_DIR="$FLAKE_DIR/logs"
if [[ -d "$LOG_DIR" ]]; then
  OLD_LOGS=$(find "$LOG_DIR" -name "*.log" -mtime +30 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$OLD_LOGS" -gt 0 ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "  [dry-run] Would delete $OLD_LOGS log file(s) older than 30 days"
    else
      find "$LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
      echo "  Deleted $OLD_LOGS old log file(s)"
    fi
  else
    echo "  No old log files"
  fi
else
  echo "  No log directory"
fi
echo ""

# 6. Summary
echo "Clean complete."
echo "  Generations: $(sudo darwin-rebuild --list-generations 2>/dev/null | wc -l | tr -d ' ' || echo "unknown")"
echo "  Store size: $(du -sh /nix/store 2>/dev/null | cut -f1 || echo "unknown")"
