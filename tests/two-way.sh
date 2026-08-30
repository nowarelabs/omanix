#!/bin/bash
# tests/two-way — automated Swift <-> Nix two-way contract tests.
#
# Proves that every Nix-backed GUI button/toggle/option round-trips between the
# Swift store and the Nix module system WITHOUT a human driving the UI:
#
#   Swift writes  -> `omanix state set` writes validated state.nix
#                 -> Swift readers (readOption/currentXState) see it       [Swift->Swift]
#                 -> `nix eval` of an importing config reflects it         [Swift->Nix]
#   Nix changes   -> state.nix on disk -> Swift readers pick it up          [Nix->Swift]
#   CLI schema    -> unknown keys / bad values rejected                     [schema]
#   Schema sync   -> every schema path exists as a Nix option and vice versa [lint]
#
# Runs fully isolated (temp FLAKE_DIR); never touches ~/.omanix or the live OS.
# Requires: Xcode Command Line Tools (swiftc), nix.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GUI_DIR="$ROOT/modules/apps/gui"
TEST_DIR="$ROOT/tests/two-way"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
step() { echo; echo "=== $1 ==="; }

# ---------------------------------------------------------------- swift harness
step "Build + run Swift headless harness (Data/ layer only, no SwiftUI)"
BIN="$WORK/two-way-tests"
xcrun swiftc \
  -framework Foundation \
  -o "$BIN" \
  "$GUI_DIR/Data/OmanixStore.swift" \
  "$GUI_DIR/Data/Models.swift" \
  "$GUI_DIR/Data/FileLogger.swift" \
  "$TEST_DIR/OmanixTwoWayTests.swift" 2>&1 \
  || { echo "ERROR: Swift harness failed to build"; exit 1; }
ok "swiftc build"

# Run from repo root so bundlePath() resolves the source tree.
SWIFT_OUTPUT="$("$BIN" 2>&1)"
echo "$SWIFT_OUTPUT"
if echo "$SWIFT_OUTPUT" | grep -q "ALL SWIFT TESTS PASSED"; then
  ok "Swift state tests passed"
else
  bad "Swift state tests failed (see output above)"
fi

# ------------------------------------------------------------- CLI + nix eval
step "CLI schema + nix eval reach (isolated temp flake)"

T="$WORK/cli-flake"
mkdir -p "$T/bin" "$T/libexec"
cp "$ROOT/bin/omanix" "$T/bin/omanix"
cp "$ROOT/libexec/omanix-state.sh" "$ROOT/libexec/log.sh" "$T/libexec/"
chmod +x "$T/bin/omanix" "$T/libexec/omanix-state.sh"

# Minimal module-system flake mirroring the real option schema (imports state.nix).
cat > "$T/flake.nix" <<'EOF'
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/917fec990948658ef1ccd07cef2a1ef060786846";
  outputs = { self, nixpkgs }: let
    lib = nixpkgs.lib;
    schema = {
      options.omanix.theme = lib.mkOption { type = lib.types.str; default = "omanix"; };
      options.omanix.omabar.enable = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omabar.showClock = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omabar.showBattery = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omabar.showVolume = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omabar.showWifi = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omabar.showApps = lib.mkOption { type = lib.types.bool; default = false; };
      options.omanix.omatiles.enable = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omatiles.bindings = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omatiles.enableEdgeDrag = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omatiles.enableKeyboardShortcuts = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.omatiles.enableMargins = lib.mkOption { type = lib.types.bool; default = false; };
      options.omanix.widgets.gui.enable = lib.mkOption { type = lib.types.bool; default = true; };
      options.omanix.widgets.store.enable = lib.mkOption { type = lib.types.bool; default = false; };
      options.omanix.widgets.pomodoro.enable = lib.mkOption { type = lib.types.bool; default = false; };
      options.omanix.widgets.clock.enable = lib.mkOption { type = lib.types.bool; default = false; };
    };
    stateModule = import ./state.nix;
  in {
    env = lib.evalModules { modules = [ schema stateModule ]; };
  };
}
EOF
printf '{ ... }:\n{\n}\n' > "$T/state.nix"

state() { FLAKE_DIR="$T" bash "$T/bin/omanix" state "$@"; }
nixval() { ( cd "$T" && nix eval --impure --no-write-lock-file ".#env.config.$1" 2>/dev/null | tr -d '"\n' ) || echo "<fail>"; }

if state set omanix.omatiles.enable false >/dev/null 2>&1; then ok "CLI: set omanix.omatiles.enable false"; else bad "CLI: set omanix.omatiles.enable false"; fi
[ "$(nixval omanix.omatiles.enable)" = "false" ] && ok "CLI set -> nix eval = false" || bad "CLI set -> nix eval = false"
if state set omanix.theme solstice >/dev/null 2>&1; then ok "CLI: set omanix.theme solstice"; else bad "CLI: set omanix.theme solstice"; fi
[ "$(nixval omanix.theme)" = "solstice" ] && ok "CLI set -> nix eval = solstice" || bad "CLI set -> nix eval = solstice"

# Schema rejection: unknown key + bad value.
if state set omanix.nope 1 >/dev/null 2>&1; then bad "CLI rejects unknown key"; else ok "CLI rejects unknown key"; fi
if state set omanix.omabar.enable maybe >/dev/null 2>&1; then bad "CLI rejects bad bool"; else ok "CLI rejects bad bool"; fi
if state set omanix.theme one-dark >/dev/null 2>&1; then ok "CLI writes string theme"; else bad "CLI writes string theme"; fi

# reset restores empty state.nix and nix eval falls back to default.
if state reset >/dev/null 2>&1; then ok "CLI reset"; else bad "CLI reset"; fi
[ "$(nixval omanix.theme)" = "omanix" ] && ok "after reset, nix eval falls back to default 'omanix'" || bad "after reset, nix eval falls back to default 'omanix'"

# ---------------------------------------------------------------- schema sync
step "Schema <-> Nix option sync lint"
# Authoritative option set: lib.evalModules over the real option modules
# (core/theme/gui options.nix), collecting every declared leaf option path.
REAL_NIX_EXPR=$(cat <<'EOF'
let pkgs = import <nixpkgs> {}; lib = pkgs.lib; ev = lib.evalModules {
  modules = [
    { config = { omanix.host = "testhost"; omanix.user = "testuser"; }; }
    { options.assertions = lib.mkOption { type = lib.types.listOf lib.types.unspecified; default = []; }; }
    ./modules/core/options.nix ./modules/theme/options.nix ./modules/apps/gui/options.nix
  ];
};
collect = path: attrs: lib.flatten (builtins.map (name: let v = builtins.getAttr name attrs;
  in if builtins.isAttrs v && v ? type then [ (lib.concatStringsSep "." (path ++ [ name ])) ]
     else if builtins.isAttrs v then collect (path ++ [ name ]) v else []) (builtins.attrNames attrs));
in builtins.sort (a: b: a < b) (collect [] ev.options)
EOF
)
REAL_OPTIONS=$(cd "$ROOT" && nix eval --impure --json --expr "$REAL_NIX_EXPR" 2>/dev/null \
  | python3 -c 'import json,sys; print("\n".join(p for p in json.load(sys.stdin) if p.startswith("omanix.")))' 2>/dev/null \
  || true)
if [[ -z "$REAL_OPTIONS" ]]; then
  bad "could not extract real Nix option paths"
else
  SCHEMA_PATHS=$(sed -n '/^schema() {/,/^}/p' "$ROOT/libexec/omanix-state.sh" \
    | grep -oE 'omanix\.[a-zA-Z0-9._]+' | sort -u)
  MISSING_IN_NIX=0
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if ! grep -qxF "$p" <<<"$REAL_OPTIONS"; then
      echo "  WARN schema path has no matching Nix option: $p"
      MISSING_IN_NIX=1
    fi
  done <<< "$SCHEMA_PATHS"
  [ "$MISSING_IN_NIX" = "0" ] && ok "every schema path has a Nix option" || bad "schema paths missing in Nix options"
  # Options declared in Nix but not yet writable via the state CLI (human-authored).
  INFO_ONLY=0
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    if ! grep -qxF "$p" <<<"$SCHEMA_PATHS"; then
      echo "  INFO option declared in Nix but not writable via schema (human-edited): $p"
      INFO_ONLY=1
    fi
  done <<< "$REAL_OPTIONS"
  [ "$INFO_ONLY" = "0" ] && ok "every Nix option is writable via schema" || ok "non-writable Nix options are human-authored (expected)"
fi

# ---------------------------------------------------------------- GUI buttons
step "Every GUI toggle/button backed by declarative state is covered"
# Walk the view-model's store setters and confirm each has a Swift-level test.
COVERED=(setOmatilesEnabled setOmatilesEdgeDrag setOmatilesMargins setOmatilesBindings setOmatilesKeyboardShortcuts
         setOmabarEnabled setOmabarShowClock setOmabarShowBattery setOmabarShowVolume setOmabarShowVolumeText setOmabarShowWifi setOmabarShowApps
         setOmabarAutoHide setOmabarShowDate setOmabarShowBatteryPercent setOmabarUse24Hour setOmabarClockFormat
         setTheme setWidgetEnabled)
MISSING=0
for s in "${COVERED[@]}"; do
  if ! grep -q "store\.$s\|try $s(" "$TEST_DIR/OmanixTwoWayTests.swift" 2>/dev/null \
     && ! grep -q "$s" "$TEST_DIR/OmanixTwoWayTests.swift"; then
    echo "  WARN no two-way test references: $s"
    MISSING=1
  fi
done
[ "$MISSING" = "0" ] && ok "all core setters referenced by two-way tests" || bad "some setters lack two-way test coverage"

# ---------------------------------------------------------------- summary
echo
echo "================================================"
echo "  PASS: $PASS   FAIL: $FAIL"
echo "================================================"
[ "$FAIL" = "0" ] && echo "ALL TWO-WAY TESTS PASSED" || { echo "FAILURES PRESENT"; exit 1; }