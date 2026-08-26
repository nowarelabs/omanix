#!/bin/bash
# libexec/log.sh — structured logging for Omanix
# Source this file: source "$FLAKE_DIR/libexec/log.sh"
#
# Logs go to ~/.omanix/logs/$(date +%Y-%m-%d).log
# Format: [TIMESTAMP] [LEVEL] [CONTEXT] message
#
# Usage:
#   log_info "install" "Adding pkgs.ripgrep"
#   log_error "rebuild" "darwin-rebuild failed"
#   log_debug "search" "Query: $query"

OMANIX_LOG_DIR="${OMANIX_LOG_DIR:-$HOME/.omanix/logs}"
OMANIX_LOG_LEVEL="${OMANIX_LOG_LEVEL:-info}"  # debug, info, warn, error

_log_level_num() {
  case "$1" in
    debug) echo 0 ;;
    info)  echo 1 ;;
    warn)  echo 2 ;;
    error) echo 3 ;;
    *)     echo 1 ;;
  esac
}

_log() {
  local level="$1"
  local context="$2"
  shift 2
  local message="$*"

  # Check if level meets threshold
  local current_num
  local threshold_num
  current_num=$(_log_level_num "$level")
  threshold_num=$(_log_level_num "$OMANIX_LOG_LEVEL")
  [ "$current_num" -lt "$threshold_num" ] && return 0

  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  local line="[$timestamp] [$level] [$context] $message"

  # Write to log file (append to daily log)
  if [ -d "$OMANIX_LOG_DIR" ] || mkdir -p "$OMANIX_LOG_DIR" 2>/dev/null; then
    echo "$line" >> "$OMANIX_LOG_DIR/$(date +%Y-%m-%d).log"
  fi

  # Echo to stderr for interactive use (never pollute stdout)
  echo "$line" >&2
}

log_debug() { _log "debug" "$@"; }
log_info()  { _log "info"  "$@"; }
log_warn()  { _log "warn"  "$@"; }
log_error() { _log "error" "$@"; }

# Log a command and its result
log_cmd() {
  local context="$1"
  shift
  local cmd="$*"
  log_info "$context" "running: $cmd"
  local start_time
  start_time=$(date +%s)
  local output
  local exit_code
  output=$("$@" 2>&1) && exit_code=0 || exit_code=$?
  local elapsed=$(( $(date +%s) - start_time ))
  if [ "$exit_code" -eq 0 ]; then
    log_info "$context" "completed in ${elapsed}s"
  else
    log_error "$context" "failed (exit $exit_code) in ${elapsed}s: ${output:0:500}"
  fi
  return "$exit_code"
}

# Rotate logs: keep last 30 days
log_rotate() {
  if [ -d "$OMANIX_LOG_DIR" ]; then
    find "$OMANIX_LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null
    log_debug "log" "rotated logs older than 30 days"
  fi
}
