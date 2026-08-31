#!/bin/bash
# tests/behavior — User does X → System shows Y (action → effect).
#
# Two services, as requested:
#   1. UserActionSimulator (does the action: Ctrl+Option+Arrow, toggle, pick theme)
#   2. SystemEffectReader  (reads the effect: window frame, defaults, theme)
#
# This suite TOUCHES THE LIVE OS (real windows, real defaults, real Omanix state)
# and therefore only runs meaningfully on macOS with a display and (for tiling)
# Accessibility. On headless CI it will SKIP the window tests and still pass the
# prefs-level checks.
#
# Usage: bash tests/behavior.sh
#        bash tests/behavior.sh --no-window  (skip window tests, just prefs)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUI_DIR="$ROOT/modules/apps/gui"
TEST_DIR="$ROOT/tests/behavior"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
step() { echo; echo "=== $1 ==="; }

if [[ "$(uname)" != "Darwin" ]]; then
  echo "SKIP: behavior tests require macOS (found $(uname))"
  exit 0
fi

if ! command -v xcrun &>/dev/null; then
  echo "SKIP: Xcode Command Line Tools not found (xcrun missing)"
  exit 0
fi

step "Build behavioral harness (UserActionSimulator + SystemEffectReader + Tiling)"

BIN="$WORK/behavior-tests"
# Swift files needed: Data layer (Omanix facade), Omatiles engine, RuntimeSettings, plus the behavior suite.
# We intentionally compile only the Data/Omatiles subset — not the full SwiftUI GUI — so the harness stays headless.
xcrun swiftc \
  -framework Foundation \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -o "$BIN" \
  "$GUI_DIR/Data/Omanix.swift" \
  "$GUI_DIR/Data/Models.swift" \
  "$GUI_DIR/Data/FileLogger.swift" \
  "$GUI_DIR/Modules/RuntimeSettings.swift" \
  "$GUI_DIR/Modules/Omatiles/LayoutEngine.swift" \
  "$GUI_DIR/Modules/Omatiles/RealWindowMover.swift" \
  "$GUI_DIR/Modules/Omatiles/GhostTilingOverlay.swift" \
  "$GUI_DIR/Modules/Omatiles/OmatilesEngine.swift" \
  "$GUI_DIR/Modules/Omatiles/KdlWorkspaceCompiler.swift" \
  $(find "$GUI_DIR/Modules/Kdl/Sources" -name '*.swift' | sort) \
  "$TEST_DIR/UserActionSimulator.swift" \
  "$TEST_DIR/SystemEffectReader.swift" \
  "$TEST_DIR/LayoutContractTests.swift" \
  "$TEST_DIR/KdlContractTests.swift" \
  "$TEST_DIR/KdlWorkspaceBehaviorTests.swift" \
  "$TEST_DIR/TilingTests.swift" \
  "$TEST_DIR/OmabarBehaviorTests.swift" \
  "$TEST_DIR/ThemeBehaviorTests.swift" \
  "$TEST_DIR/BehaviorTests.swift" 2>&1 \
  || { echo "ERROR: behavioral harness failed to build"; exit 1; }
ok "swiftc build"

step "Run behavioral tests (action → effect)"
# The harness itself prints PASS/FAIL/SKIP per sub-test; we just check the summary.
set +e
OUTPUT="$("$BIN" 2>&1)"
STATUS=$?
set -e
echo "$OUTPUT"

if echo "$OUTPUT" | grep -q "ALL BEHAVIORAL TESTS PASSED"; then
  ok "Behavioral suite passed"
else
  if [[ $STATUS -eq 0 ]]; then
    # All window tests SKIPPED but prefs tests passed — still a pass.
    if echo "$OUTPUT" | grep -q "FAIL"; then
      bad "Behavioral suite had failures (see above)"
    else
      ok "Behavioral suite passed (some SKIPPED)"
    fi
  else
    bad "Behavioral suite failed"
  fi
fi

echo
echo "================================================"
echo "  PASS: $PASS   FAIL: $FAIL"
echo "================================================"
[ "$FAIL" = "0" ] && echo "ALL BEHAVIOR CHECKS PASSED" || { echo "FAILURES PRESENT"; exit 1; }
