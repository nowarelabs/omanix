# modules/apps/store/default.nix — Omanix Store GUI (SwiftUI)
# Enabled by default (omanix.widgets.store.enable = true)
# Builds a real SwiftUI app and installs to /Applications
{ config, lib, pkgs, ... }:

let
  enabled = config.omanix.widgets.store.enable;
  user = config.omanix.user;

  # Build the SwiftUI app
  omanix-store = pkgs.stdenv.mkDerivation {
    pname = "omanix-store";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = with pkgs; [
      swift
      swiftui
    ];

    buildPhase = ''
      # Create app bundle structure
      mkdir -p $out/Applications/Omanix\ Store.app/Contents/MacOS
      mkdir -p $out/Applications/Omanix\ Store.app/Contents/Resources

      # Compile Swift sources
      swiftc \
        -sdk ${pkgs.darwin.apple_sdk.frameworks.SwiftUI}/Library/Frameworks \
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

    installPhase = "true"; # Already built to $out

    meta = with lib; {
      description = "Omanix Store — browse and install packages";
      homepage = "https://github.com/nowarelabs/omanix";
      license = licenses.mit;
      maintainers = [ ];
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

    # Create a symlink for easy access
    environment.systemPackages = [ omanix-store ];

    # Add to PATH for CLI access
    home-manager.users.${user}.home.sessionPath = [
      "${omanix-store}/Applications/Omanix Store.app/Contents/MacOS"
    ];
  };
}
