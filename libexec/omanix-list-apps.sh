#!/bin/bash
# libexec/omanix-list-apps.sh — list installed custom apps
set -euo pipefail
source "$(dirname "$0")/omanix-helpers.sh"
_omanix_init "list-apps"

usage() {
  cat <<EOF
Usage: omanix list-apps

List installed custom apps in /Applications.

Examples:
  omanix list-apps
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_installed

header "Apps"

FOUND=false
for app in "$HOME/.local/bin/install-"*; do
  [[ -f "$app" ]] || continue
  FOUND=true
  name=$(basename "$app" | sed 's/^install-//')
  APP_PATH="/Applications/${name}.app"
  if [[ ! -d "$APP_PATH" ]]; then
    APP_PATH="/Applications/$(echo "$name" | sed 's/-/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' | sed 's/ //g').app"
  fi
  if [[ -d "$APP_PATH" ]]; then
    echo "  ✓ $name"
  else
    echo "  ○ $name (not installed)"
  fi
done

if [[ "$FOUND" == "false" ]]; then
  echo "  No custom apps found"
fi
