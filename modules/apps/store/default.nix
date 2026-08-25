# modules/apps/store/default.nix — Omanix Store GUI (SwiftUI)
# Builds using system Swift outside Nix sandbox
{ config, lib, pkgs, ... }:

let
  enabled = config.omanix.widgets.store.enable;
  user = config.omanix.user;

  # Store the source files (don't compile in Nix)
  store-src = ./.;

in {
  config = lib.mkIf enabled {
    # Build and install the app on system activation
    system.activationScripts.omanix-store = {
      text = ''
        echo "Building Omanix Store..."
        STORE_DIR="$HOME/.omanix-store"
        mkdir -p "$STORE_DIR"

        # Copy source files
        cp -R ${store-src}/Sources "$STORE_DIR/"

        # Build with system Swift
        if command -v xcrun &>/dev/null; then
          mkdir -p "/Applications/Omanix Store.app/Contents/MacOS"
          mkdir -p "/Applications/Omanix Store.app/Contents/Resources"

          xcrun swiftc \
            -framework SwiftUI \
            -framework Foundation \
            -o "/Applications/Omanix Store.app/Contents/MacOS/Omanix Store" \
            "$STORE_DIR/Sources/"*.swift

          # Create Info.plist
          cat > "/Applications/Omanix Store.app/Contents/Info.plist" << 'PLIST'
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
          <plist version="1.0">
          <dict>
            <key>CFBundleExecutable</key>
            <string>Omanix Store</string>
            <key>CFBundleIdentifier</key>
            <string>dev.omanix.store</string>
            <key>CFBundleName</key>
            <string>Omanix Store</string>
            <key>CFBundleDisplayName</key>
            <string>Omanix Store</string>
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
          </dict>
          </plist>
          PLIST

          echo "Omanix Store built successfully"
        else
          echo "WARNING: Xcode Command Line Tools not found, skipping Store build"
          echo "Install with: xcode-select --install"
        fi
      '';
    };

    # Add build script to PATH for manual rebuilds
    home-manager.users.${user}.home.file.".local/bin/build-omanix-store" = {
      text = ''
        #!/bin/bash
        # Rebuild Omanix Store manually
        STORE_DIR="$HOME/.omanix-store"
        mkdir -p "$STORE_DIR"

        # Copy source from nix store or config dir
        CONFIG_DIR="$HOME/.config/omanix"
        if [[ -d "$CONFIG_DIR/modules/apps/store/Sources" ]]; then
          cp -R "$CONFIG_DIR/modules/apps/store/Sources" "$STORE_DIR/"
        fi

        # Build
        mkdir -p "/Applications/Omanix Store.app/Contents/MacOS"
        mkdir -p "/Applications/Omanix Store.app/Contents/Resources"

        xcrun swiftc \
          -framework SwiftUI \
          -framework Foundation \
          -o "/Applications/Omanix Store.app/Contents/MacOS/Omanix Store" \
          "$STORE_DIR/Sources/"*.swift

        echo "Omanix Store rebuilt successfully"
        echo "Open with: open -a 'Omanix Store'"
      '';
      executable = true;
    };
  };
}
