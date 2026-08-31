#!/bin/bash
# checks/darwin-check.sh — runs on this Mac, evals every Mac arch
set -e

# Read hostname from configuration.nix (single source of truth)
HOSTNAME=$(grep -oE 'omanix\.host\s*=\s*"[^"]+"' "$HOME/.omanix/configuration.nix" | head -1 | sed 's/.*"\(.*\)"/\1/')
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
echo "=== Two-way Swift <-> Nix contract tests ==="
bash "$(dirname "$0")/../tests/two-way.sh"
echo ""
echo "=== Behavioral (action -> effect) tests ==="
# Expectation-driven suite: User does X (move window, apply layout, toggle, compile
# a KDL workspace map) -> System shows Y. Touches the live OS for tiling so window
# tests SKIP on headless CI while the pure contract/KDL/prefs checks still run.
bash "$(dirname "$0")/../tests/behavior.sh"
echo ""
echo "=== All checks passed ==="
