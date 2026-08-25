# modules/apps/store/default.nix — Omanix Store GUI (SwiftUI on mac, GTK on linux)
# Enabled by default (omanix.widgets.store.enable = true)
# See conventions.md:14 and principles.md:14
{ config, lib, pkgs, ... }:
let
  enabled = config.omanix.widgets.store.enable;
in {
  config = lib.mkIf enabled {
    # The Store is a widget — appears as /Applications/Omanix Store.app
    # TODO: Phase 06 — build real SwiftUI app in Sources/
    # For now, placeholder that calls omanix CLI helpers
    home.file."Applications/Omanix Store.app" = {
      source = pkgs.runCommand "omanix-store-app" {
        nativeBuildInputs = with pkgs; [ ];
      } ''
        mkdir -p $out/Omanix\ Store.app/Contents/MacOS
        mkdir -p $out/Omanix\ Store.app/Contents/Resources
        cat > $out/Omanix\ Store.app/Contents/Info.plist << 'PLIST'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleName</key><string>Omanix Store</string>
          <key>CFBundleIdentifier</key><string>org.omanix.store</string>
          <key>CFBundleVersion</key><string>1.0</string>
          <key>CFBundleShortVersionString</key><string>1.0</string>
          <key>LSMinimumSystemVersion</key><string>12.0</string>
          <key>LSUIElement</key><true/>
        </dict>
        </plist>
        PLIST
        cat > $out/Omanix\ Store.app/Contents/MacOS/Omanix\ Store << 'BASH'
        #!/bin/bash
        echo "Omanix Store — coming soon"
        echo "Use 'omanix add <package>' in the meantime"
        echo ""
        echo "Press any key to exit..."
        read -n 1
        BASH
        chmod +x "$out/Omanix Store.app/Contents/MacOS/Omanix Store"
      '';
    };

    # Launchd agent to keep Store accessible
    launchd.user.agents.omanix-store = {
      serviceConfig = {
        ProgramArguments = [ "/bin/echo" "Omanix Store is a derivation, not a daemon" ];
        KeepAlive = false;
        RunAtLoad = false;
      };
    };
  };
}
