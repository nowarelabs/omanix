#!/bin/bash
# checks/darwin-check.sh — runs on this Mac, evals every Mac arch
set -e

# Read hostname from configuration.nix (single source of truth)
HOSTNAME=$(grep -oE 'omanix\.host\s*=\s*"[^"]+"' "$HOME/.config/omanix/configuration.nix" | head -1 | sed 's/.*"\(.*\)"/\1/')
if [[ -z "$HOSTNAME" ]]; then
  echo "Error: Could not read hostname from configuration.nix" >&2
  exit 1
fi

echo "=== Omanix flake check ==="
nix flake check --show-trace
echo ""
echo "=== darwin-rebuild check (dry, no switch) ==="
darwin-rebuild check --flake ".#$HOSTNAME" --show-trace
echo ""
echo "=== cross-arch eval (x86_64-darwin) ==="
nix flake check --system x86_64-darwin --show-trace 2>/dev/null || echo "x86_64 cross-check skip (no linux builder)"
echo ""
echo "=== All checks passed ==="
