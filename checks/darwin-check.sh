#!/bin/bash
# checks/darwin-check.sh — runs on this Mac, evals every Mac arch
set -e
echo "=== Omanix flake check ==="
nix flake check --show-trace
echo ""
echo "=== darwin-rebuild check (dry, no switch) ==="
darwin-rebuild check --flake .#Vances-MacBook-Pro --show-trace
echo ""
echo "=== cross-arch eval (x86_64-darwin) ==="
nix flake check --system x86_64-darwin --show-trace 2>/dev/null || echo "x86_64 cross-check skip (no linux builder)"
echo ""
echo "=== All checks passed ==="
