#!/bin/bash
# libexec/omanix-ask.sh — ask AI (frontier or local)
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "ask"

LOCAL=false

usage() {
  cat <<EOF
Usage: omanix ask [options] <prompt>

Ask AI for help with Omanix configuration or development.

Options:
  --local     Use local Qwen model (offline, no API key)
  -h, --help  Show this help

Examples:
  omanix ask "how do I add a theme?"
  omanix ask --local "explain my configuration.nix"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local) LOCAL=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) log_error "unknown option: $1"; usage >&2; exit 1 ;;
    *) break ;;
  esac
done

if [[ $# -eq 0 ]]; then
  log_error "missing prompt"
  usage >&2
  exit 1
fi

PROMPT="$*"

header "Ask"

if [[ "$LOCAL" == "true" ]]; then
  log_info "asking local Qwen"
  echo "Asking local Qwen..."
  # TODO: Phase 07 — ollama run qwen2.5:7b --skill skills/omanix/mini-SKILL.md -- "$PROMPT"
  echo "Local AI not yet configured. Run 'omanix setup local-ai' first."
else
  log_info "asking frontier Claude"
  echo "Asking frontier Claude..."
  # TODO: Phase 07 — claude --skill skills/omanix/SKILL.md -- "$PROMPT"
  echo "Frontier AI not yet configured."
fi
