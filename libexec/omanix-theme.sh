#!/bin/bash
# libexec/omanix-theme.sh — theme CLI: list, set, preview, new
# See docs/themes.md and lib/themed.nix
set -e

FLAKE_DIR="${FLAKE_DIR:-$HOME/.omanix}"
CONFIG="$FLAKE_DIR/configuration.nix"

usage() {
  cat <<EOF
Usage: omanix theme <subcommand> [args]

Subcommands:
  list                    List available themes (from themes/)
  current                 Show current theme
  set <name>              Set omanix.theme in configuration.nix (then run omanix rebuild)
  preview <name>          Preview theme impurely (no generation, like omanix rebuild --preview)
  new <name>              Scaffold a new theme in themes/<name>/ (community submission)
  per-app <app> <key> <value>  Set per-app override (e.g. per-app ghostty background "#000000")
  transition <on|off>     Toggle transition animation
EOF
}

list_themes() {
  echo "Available themes (from themes/):"
  for d in "$FLAKE_DIR"/themes/*/; do
    [[ -d "$d" ]] || continue
    name=$(basename "$d")
    accent=$(grep '^accent' "$d/colors.toml" 2>/dev/null | cut -d'"' -f2 || echo "?")
    bg=$(grep '^background' "$d/colors.toml" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "?")
    printf "  %-16s accent %s  bg %s\n" "$name" "$accent" "$bg"
  done
}

current_theme() {
  if [[ -f "$HOME/.config/omanix/theme.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -r '.name' "$HOME/.config/omanix/theme.json" 2>/dev/null || cat "$HOME/.config/omanix/theme.json"
    else
      cat "$HOME/.config/omanix/theme.json" | grep -o '"name":"[^"]*"' | cut -d'"' -f4
    fi
  elif grep -q 'omanix.theme' "$CONFIG" 2>/dev/null; then
    grep 'omanix.theme' "$CONFIG" | head -1
  else
    echo "unknown (not set)"
  fi
}

set_theme() {
  local name="$1"
  if [[ -z "$name" ]]; then echo "Usage: omanix theme set <name>" >&2; exit 1; fi
  if [[ ! -f "$FLAKE_DIR/themes/$name/colors.toml" ]]; then
    echo "Theme '$name' not found. Run 'omanix theme list'." >&2
    exit 1
  fi
  # Rewrite configuration.nix option
  if grep -q 'omanix.theme' "$CONFIG"; then
    # Use sed for simple rewrite (preserves comments)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/omanix\.theme = \"[^\"]*\"/omanix.theme = \"$name\"/" "$CONFIG"
    else
      sed -i "s/omanix\.theme = \"[^\"]*\"/omanix.theme = \"$name\"/" "$CONFIG"
    fi
  else
    echo "  omanix.theme = \"$name\";" >> "$CONFIG"
  fi
  echo "Set omanix.theme = \"$name\" in $CONFIG"
  echo "Run 'omanix rebuild' to apply (or 'omanix rebuild --preview' for instant preview)."
}

preview_theme() {
  local name="$1"
  if [[ -z "$name" ]]; then echo "Usage: omanix theme preview <name>" >&2; exit 1; fi
  echo "Previewing $name (impure, no generation)..."
  # Set theme then run preview rebuild if available
  set_theme "$name"
  if [[ -f "$FLAKE_DIR/libexec/omanix-rebuild.sh" ]]; then
    exec "$FLAKE_DIR/libexec/omanix-rebuild.sh" --preview
  else
    echo "Preview: would run 'omanix rebuild --preview' (rebuild script not found)"
  fi
}

new_theme() {
  local name="$1"
  if [[ -z "$name" ]]; then echo "Usage: omanix theme new <name>" >&2; exit 1; fi
  if [[ -d "$FLAKE_DIR/themes/$name" ]]; then echo "Theme '$name' already exists at themes/$name" >&2; exit 1; fi
  # Copy from tokyo-night as template
  local src="$FLAKE_DIR/themes/tokyo-night"
  if [[ ! -d "$src" ]]; then src=$(ls -d "$FLAKE_DIR"/themes/*/ | head -1); fi
  mkdir -p "$FLAKE_DIR/themes/$name/backgrounds"
  cp "$src/colors.toml" "$FLAKE_DIR/themes/$name/colors.toml"
  cp "$src/icons.theme" "$FLAKE_DIR/themes/$name/icons.theme" 2>/dev/null || echo "Yaru" > "$FLAKE_DIR/themes/$name/icons.theme"
  cp "$src/vscode.json" "$FLAKE_DIR/themes/$name/vscode.json" 2>/dev/null || echo '{"name":"'"$name"'"}' > "$FLAKE_DIR/themes/$name/vscode.json"
  cp "$src/neovim.lua" "$FLAKE_DIR/themes/$name/neovim.lua" 2>/dev/null || true
  echo "Scaffolded themes/$name/"
  echo "Next:"
  echo "  1. Edit themes/$name/colors.toml (see docs/themes.md)"
  echo "  2. Add \"$name\" to modules/core/options.nix enum"
  echo "  3. nix flake check"
  echo "  4. omanix theme set $name && omanix rebuild"
  echo "  5. PR with preview.png + vscode.json (see COMMUNITY)"
}

per_app() {
  local app="$1" key="$2" val="$3"
  if [[ -z "$app" || -z "$key" || -z "$val" ]]; then
    echo "Usage: omanix theme per-app <ghostty> <key> <value>" >&2
    echo "Example: omanix theme per-app ghostty background \"#000000\"" >&2
    exit 1
  fi
  local opt="omanix.perApp.$app.$key"
  # Use rewrite similar to Omanix's rewriteOption
  if grep -q "$opt" "$CONFIG"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s|$opt = \"[^\"]*\"|$opt = \"$val\"|" "$CONFIG"
    else
      sed -i "s|$opt = \"[^\"]*\"|$opt = \"$val\"|" "$CONFIG"
    fi
  else
    echo "  $opt = \"$val\";" >> "$CONFIG"
  fi
  echo "Set $opt = \"$val\" — run omanix rebuild"
}

transition_toggle() {
  local v="$1"
  # Primary: omanix.transition.enable (spec alias omanix.theme.transition.enable also handled via sed)
  if [[ "$v" == "on" || "$v" == "true" ]]; then
    if grep -q 'omanix\.transition\.enable' "$CONFIG" || grep -q 'omanix\.theme\.transition\.enable' "$CONFIG"; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' 's/omanix\.transition\.enable = false/omanix.transition.enable = true/' "$CONFIG" 2>/dev/null || true
        sed -i '' 's/omanix\.theme\.transition\.enable = false/omanix.theme.transition.enable = true/' "$CONFIG" 2>/dev/null || true
        sed -i '' 's/omanix\.theme\.transition\.enable = false/omanix.transition.enable = true/' "$CONFIG" 2>/dev/null || true
      else
        sed -i 's/omanix\.transition\.enable = false/omanix.transition.enable = true/' "$CONFIG" 2>/dev/null || true
        sed -i 's/omanix\.theme\.transition\.enable = false/omanix.theme.transition.enable = true/' "$CONFIG" 2>/dev/null || true
      fi
    else
      echo '  omanix.transition.enable = true;' >> "$CONFIG"
    fi
    echo "Transitions enabled (omanix.transition.enable = true)"
  elif [[ "$v" == "off" || "$v" == "false" ]]; then
    if grep -q 'omanix\.transition\.enable\|omanix\.theme\.transition\.enable' "$CONFIG"; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' 's/omanix\.transition\.enable = true/omanix.transition.enable = false/' "$CONFIG" 2>/dev/null || true
        sed -i '' 's/omanix\.theme\.transition\.enable = true/omanix.theme.transition.enable = false/' "$CONFIG" 2>/dev/null || true
      else
        sed -i 's/omanix\.transition\.enable = true/omanix.transition.enable = false/' "$CONFIG" 2>/dev/null || true
        sed -i 's/omanix\.theme\.transition\.enable = true/omanix.theme.transition.enable = false/' "$CONFIG" 2>/dev/null || true
      fi
    else
      echo '  omanix.transition.enable = false;' >> "$CONFIG"
    fi
    echo "Transitions disabled (omanix.transition.enable = false)"
  else
    echo "Usage: omanix theme transition <on|off>" >&2; exit 1
  fi
}

cmd="${1:-help}"
case "$cmd" in
  list) list_themes ;;
  current) current_theme ;;
  set) set_theme "$2" ;;
  preview) preview_theme "$2" ;;
  new) new_theme "$2" ;;
  per-app) per_app "$2" "$3" "$4" ;;
  transition) transition_toggle "$2" ;;
  help|--help|-h|"") usage ;;
  *) echo "Unknown subcommand: $cmd" >&2; usage >&2; exit 1 ;;
esac
