# modules/apps/gui/default.nix — Omanix GUI (SwiftUI) preview build
# Same pattern as modules/apps/store/default.nix: builds with system Swift
# outside the Nix sandbox, copies sources from the config dir for live edits.
{ config, lib, pkgs, ... }:

let
  enabled = config.omanix.widgets.gui.enable;
  user = config.omanix.user;
  gui-src = ./.;

  # Pre-build the Info.plist as a nix store path so we don't need a heredoc
  infoPlist = pkgs.writeText "Info.plist" ''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Omanix</string>
  <key>CFBundleIdentifier</key>
  <string>dev.omanix.gui</string>
  <key>CFBundleName</key>
  <string>Omanix</string>
  <key>CFBundleDisplayName</key>
  <string>Omanix</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>'';

in {
  config = lib.mkIf enabled {
    system.activationScripts.postActivation.text = lib.mkAfter ''
STORE_DIR="$HOME/.omanix"
LOG_DIR="$STORE_DIR/logs"
mkdir -p "$STORE_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] [gui-build] $2" >> "$LOG_FILE"; echo "[$1] [gui-build] $2"; }

log "INFO" "starting Omanix GUI build"

# Copy source files from config directory (not nix store, which is cached)
CONFIG_DIR="/Users/${user}/.omanix"
# Purge stale copies first: activation runs as root, so $STORE_DIR is
# /var/root/.omanix and may hold files deleted from the flake since.
rm -rf "$STORE_DIR/gui"
if [ -d "$CONFIG_DIR/modules/apps/gui" ]; then
  cp -R -p "$CONFIG_DIR/modules/apps/gui" "$STORE_DIR/gui"
  log "INFO" "copied gui sources from config directory"
else
  cp -R -p ${gui-src} "$STORE_DIR/gui"
  log "INFO" "copied gui sources from nix store"
fi

# Build with system Swift into the same app bundle.
# Incremental: only recompile when a source is actually newer than the installed
# binary. Building on every activation replaced the executable, so macOS silently
# revoked the Accessibility permission (it is keyed to the binary's signature).
XCRUN="/usr/bin/xcrun"
if [ -x "$XCRUN" ] || command -v xcrun >/dev/null 2>&1; then
  mkdir -p "/Applications/Omanix.app/Contents/MacOS"
  mkdir -p "/Applications/Omanix.app/Contents/Resources"

  # Only compile gui sources (not store sources) — both define @main and would clash
  GUI_DIR="$STORE_DIR/gui"
  if [ -d "$GUI_DIR" ]; then
    BUNDLE="/Applications/Omanix.app"
    BIN="$BUNDLE/Contents/MacOS/Omanix"

    NEEDS_BUILD=1
    if [ -x "$BIN" ]; then
      if [ -z "$(find "$GUI_DIR" -name '*.swift' -newer "$BIN" | head -1)" ]; then
        NEEDS_BUILD=0
      fi
    fi

    if [ "$NEEDS_BUILD" = "1" ]; then
      echo "Building Omanix GUI..."
      # shellcheck disable=SC2046
      "$XCRUN" swiftc \
        -framework SwiftUI \
        -framework Foundation \
        -framework CoreAudio \
        -o "$BIN" \
        $(find "$GUI_DIR" -name '*.swift' | sort)
      echo "Omanix GUI rebuilt"
    else
      echo "Omanix GUI up to date — skipping rebuild (keeps the Accessibility grant)"
    fi

    cp ${infoPlist} "$BUNDLE/Contents/Info.plist"
    cp ${../../../assets/Omanix.icns} "$STORE_DIR/icon.icns"
    cp ${../../../assets/Omanix.icns} "$BUNDLE/Contents/Resources/AppIcon.icns"

    # Ad-hoc sign the whole bundle so the Accessibility (TCC) grant keys on one
    # stable identity. Required after a rebuild; no-op-identical when skipped.
    codesign --force --sign - "$BUNDLE" 2>/dev/null || true

    # Restart the per-user module agents onto the (possibly rebuilt) binary so
    # they pick it up without a logout. They run as the user, so they share the
    # GUI's Accessibility permission rather than needing a root grant.
    USER_UID="$(id -u ${user} 2>/dev/null || echo 501)"
    launchctl kickstart -k "gui/$USER_UID/om.omanix.omabar" 2>/dev/null || true
    launchctl kickstart -k "gui/$USER_UID/om.omanix.omatiles" 2>/dev/null || true

    chown -R ${user}:admin "$BUNDLE"

    log "INFO" "Omanix GUI built successfully"
    echo "Omanix GUI built successfully"
  else
    echo "WARNING: gui sources not found, skipping build"
  fi
else
  echo "WARNING: Xcode Command Line Tools not found, skipping Omanix GUI build"
  echo "Install with: xcode-select --install"
fi
    '';
  };
}
