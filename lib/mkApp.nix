# lib/mkApp.nix — SDK for creating Omanix native apps
# Takes { name, bundleId, src } → /Applications/*.app derivation on darwin
# See conventions.md:5 and principles.md:10
{ lib, pkgs }:

{ name
, bundleId ? "org.omanix.${lib.toLower name}"
, src ? null
, plistConfig ? {}
}:
let
  isDarwin = pkgs.stdenv.isDarwin;
in {
  # Swift app bundle (darwin) or .desktop file (linux)
  home.file = lib.optionalAttrs isDarwin {
    "Applications/${name}.app" = {
      source = if src != null then src else pkgs.runCommand "${name}-app" {
        nativeBuildInputs = with pkgs; [ swift ];
      } ''
        mkdir -p $out/${name}.app/Contents/MacOS
        mkdir -p $out/${name}.app/Contents/Resources
        cat > $out/${name}.app/Contents/Info.plist << 'PLIST'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleName</key><string>${name}</string>
          <key>CFBundleIdentifier</key><string>${bundleId}</key>
          <key>CFBundleVersion</key><string>1.0</string>
          <key>CFBundleShortVersionString</key><string>1.0</string>
          <key>LSMinimumSystemVersion</key><string>12.0</string>
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "<key>${n}</key><${if builtins.isBool v then "true" else "string"}>${toString v}</${if builtins.isBool v then "true" else "string"}>") plistConfig)}
        </dict>
        </plist>
        PLIST
        # Placeholder binary
        echo '#!/bin/bash
        echo "${name} widget — Omanix derivation"
        echo "Replace with real Swift app in modules/apps/${lib.toLower name}/"' > $out/${name}.app/Contents/MacOS/${name}
        chmod +x $out/${name}.app/Contents/MacOS/${name}
      '';
    };
  };
}
