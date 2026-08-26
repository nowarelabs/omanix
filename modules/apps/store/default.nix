# modules/apps/store/default.nix — Omanix Store GUI (SwiftUI)
# Builds using system Swift outside Nix sandbox
{ config, lib, pkgs, ... }:

let
  enabled = config.omanix.widgets.store.enable;
  user = config.omanix.user;
  store-src = ./.;

  # Pre-build the Info.plist as a nix store path so we don't need a heredoc
  infoPlist = pkgs.writeText "Info.plist" ''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Omanix</string>
  <key>CFBundleIdentifier</key>
  <string>dev.omanix.app</string>
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

  # App icon - copy to nix store
  appIcon = pkgs.runCommand "omanix-icon" {} ''
    mkdir -p $out
    cp ${../../../assets/icon.png} $out/AppIcon.icns
  '';

in {
  config = lib.mkIf enabled {
    system.activationScripts.postActivation.text = ''
STORE_DIR="$HOME/.omanix-store"
mkdir -p "$STORE_DIR"

# Copy source files
cp -R ${store-src}/Sources "$STORE_DIR/"

# Build with system Swift
XCRUN="/usr/bin/xcrun"
if [ -x "$XCRUN" ] || command -v xcrun >/dev/null 2>&1; then
  mkdir -p "/Applications/Omanix.app/Contents/MacOS"
  mkdir -p "/Applications/Omanix.app/Contents/Resources"

  echo "Building Omanix..."
  "$XCRUN" swiftc \
    -framework SwiftUI \
    -framework Foundation \
    -o "/Applications/Omanix.app/Contents/MacOS/Omanix" \
    "$STORE_DIR/Sources/"*.swift

  cp ${infoPlist} "/Applications/Omanix.app/Contents/Info.plist"
  cp ${../../../assets/icon.png} "$HOME/.omanix-store/icon.png"
  cp ${../../../assets/icon.png} "/Applications/Omanix.app/Contents/Resources/AppIcon.icns"

  # Fix ownership so build-omanix can overwrite later
  chown -R ${user}:admin /Applications/Omanix.app

  echo "Omanix built successfully"

  # Add to Login Items for auto-launch (if not already added)
  if ! osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | grep -q "^Omanix$"; then
    echo "Adding Omanix to Login Items..."
    osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Omanix.app", hidden:false}' 2>/dev/null || true
  fi
else
  echo "WARNING: Xcode Command Line Tools not found, skipping Omanix build"
  echo "Install with: xcode-select --install"
fi
    '';

    home-manager.users.${user}.home.file.".local/bin/build-omanix" = {
      text = ''
#!/bin/bash
STORE_DIR="$HOME/.omanix-store"
mkdir -p "$STORE_DIR"

CONFIG_DIR="$HOME/.config/omanix"
if [ -d "$CONFIG_DIR/modules/apps/store/Sources" ]; then
  cp -R "$CONFIG_DIR/modules/apps/store/Sources" "$STORE_DIR/"
fi

# Fix ownership if needed (darwin-rebuild creates with root)
if [ -O "/Applications/Omanix.app/Contents/MacOS" ]; then
  : # already owned by us
else
  sudo chown -R "$(whoami):admin" "/Applications/Omanix.app"
fi

mkdir -p "/Applications/Omanix.app/Contents/MacOS"
mkdir -p "/Applications/Omanix.app/Contents/Resources"

xcrun swiftc \
  -framework SwiftUI \
  -framework Foundation \
  -o "/Applications/Omanix.app/Contents/MacOS/Omanix" \
  "$STORE_DIR/Sources/"*.swift

# Copy icon from config directory if it exists
if [ -f "$CONFIG_DIR/assets/icon.png" ]; then
  cp "$CONFIG_DIR/assets/icon.png" "/Applications/Omanix.app/Contents/Resources/AppIcon.icns"
fi

echo "Omanix rebuilt successfully"
      '';
      executable = true;
    };
  };
}
