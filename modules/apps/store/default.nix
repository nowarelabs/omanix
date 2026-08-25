# modules/apps/store/default.nix — Omanix Store GUI (SwiftUI)
# Builds a real SwiftUI app using system Swift compiler
{ config, lib, pkgs, ... }:

let
  enabled = config.omanix.widgets.store.enable;
  user = config.omanix.user;

  # Build the SwiftUI app using system Swift (requires Xcode CLI tools)
  omanix-store = pkgs.stdenv.mkDerivation {
    pname = "omanix-store";
    version = "0.1.0";

    src = ./.;

    # Don't use nix swift - use system Swift via xcrun
    dontBuild = true;
    dontFixup = true;

    postPatch = ''
      # Check for Xcode Command Line Tools
      if ! command -v xcrun &>/dev/null; then
        echo "ERROR: Xcode Command Line Tools not found."
        echo "Install with: xcode-select --install"
        echo "Then run: omanix rebuild"
        exit 1
      fi
    '';

    installPhase = ''
      mkdir -p $out/Applications/Omanix\ Store.app/Contents/MacOS
      mkdir -p $out/Applications/Omanix\ Store.app/Contents/Resources

      # Compile with system Swift (requires Xcode Command Line Tools)
      xcrun swiftc \
        -framework SwiftUI \
        -framework Foundation \
        -o $out/Applications/Omanix\ Store.app/Contents/MacOS/Omanix\ Store \
        Sources/*.swift

      # Create Info.plist
      cat > $out/Applications/Omanix\ Store.app/Contents/Info.plist << 'PLIST'
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
    '';

    meta = with lib; {
      description = "Omanix Store — browse and install packages";
      homepage = "https://github.com/nowarelabs/omanix";
      license = licenses.mit;
    };
  };

in {
  config = lib.mkIf enabled {
    # Install the app to /Applications
    system.activationScripts.omanix-store = {
      text = ''
        echo "Installing Omanix Store..."
        cp -R ${omanix-store}/Applications/Omanix\ Store.app /Applications/
      '';
    };

    # Add to system packages
    environment.systemPackages = [ omanix-store ];
  };
}
