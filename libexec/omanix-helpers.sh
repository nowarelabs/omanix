#!/bin/bash
# libexec/omanix-helpers.sh — shared helper functions for all omanix scripts
# Source this file: source "$FLAKE_DIR/libexec/omanix-helpers.sh"

# --- Logging ---
_log() {
  local level="$1" ctx="$2" msg="$3"
  echo "[$level] [$ctx] $msg"
  [[ -f "$_LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$ctx] $msg" >> "$_LOG_FILE"
}

log_info()  { _log "INFO"  "$1" "$2"; }
log_warn()  { _log "WARN"  "$1" "$2"; }
log_error() { _log "ERROR" "$1" "$2" >&2; }
log_debug() { [[ "${OMANIX_LOG_LEVEL:-}" == "debug" ]] && _log "DEBUG" "$1" "$2"; return 0; }

# --- Validation helpers ---
require_arg() {
  local name="$1" value="$2"
  if [[ -z "$value" ]]; then
    log_error "$_CMD" "missing required argument: $name"
    echo "Run 'omanix $_CMD --help' for usage" >&2
    exit 1
  fi
}

require_command() {
  local cmd="$1" purpose="${2:-}"
  if ! command -v "$cmd" &>/dev/null; then
    log_error "$_CMD" "required command not found: $cmd"
    [[ -n "$purpose" ]] && echo "Needed for: $purpose" >&2
    echo "Install it and try again" >&2
    exit 1
  fi
}

require_file() {
  local path="$1" purpose="${2:-}"
  if [[ ! -f "$path" ]]; then
    log_error "$_CMD" "required file not found: $path"
    [[ -n "$purpose" ]] && echo "$purpose" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1" purpose="${2:-}"
  if [[ ! -d "$path" ]]; then
    log_error "$_CMD" "required directory not found: $path"
    [[ -n "$purpose" ]] && echo "$purpose" >&2
    exit 1
  fi
}

require_installed() {
  require_dir "$FLAKE_DIR" "Omanix not installed. Run 'curl -fsSL https://raw.githubusercontent.com/nowarelabs/omanix/main/bin/install | sh -s -- install'"
  require_file "$FLAKE_DIR/configuration.nix" "configuration.nix not found. Is Omanix properly installed?"
}

# --- Input helpers ---
confirm() {
  local prompt="${1:-Continue?}"
  read -p "$prompt (y/n) " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    log_info "$_CMD" "sudo access required"
    sudo echo "" || {
      log_error "$_CMD" "sudo access denied"
      echo "Omanix requires sudo for system configuration" >&2
      exit 1
    }
  fi
}

# --- Output helpers ---
header() {
  local title="$1"
  echo ""
  echo "Omanix $title"
  echo "$(printf '=%.0s' $(seq 1 ${#title}))" | sed "s/^/Omanix /;s/Omanix $title//"
  echo ""
}

step() {
  local num="$1" desc="$2"
  echo "[$num] $desc"
  log_info "$_CMD" "step $num: $desc"
}

summary() {
  local msg="${1:-Complete}"
  echo ""
  echo "$msg"
}

# --- Setup (call at start of each script) ---
_omanix_init() {
  _CMD="${1:-unknown}"
  FLAKE_DIR="${FLAKE_DIR:-$HOME/.omanix}"
  _LOG_DIR="$FLAKE_DIR/logs"
  _LOG_FILE="$_LOG_DIR/$(date '+%Y-%m-%d').log"
  mkdir -p "$_LOG_DIR" 2>/dev/null || true

  if [[ -f "$FLAKE_DIR/libexec/log.sh" ]]; then
    source "$FLAKE_DIR/libexec/log.sh"
  fi
}
