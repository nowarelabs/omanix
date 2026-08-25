# lib/mkCustomApp.nix — reusable installer/uninstaller for apps not in Homebrew
# Takes { name, description, url, type } → { installScript, uninstallScript }
# Used by modules/apps/custom.nix
{ lib, pkgs }:

{ name
, description ? "${name}"
, url ? ""
, type ? "dmg" # "dmg" or "zip"
, appPath ? "/Applications/${name}.app"
}:

let
  safeName = lib.toLower (builtins.replaceStrings [" "] ["-" ] name);

  installScript = pkgs.writeShellScript "install-${safeName}" ''
    set -euo pipefail

    APP_NAME="${name}"
    APP_URL="${url}"
    APP_TYPE="${type}"
    DEST="${appPath}"

    if [ -z "$APP_URL" ]; then
      echo "ERROR: No download URL configured for $APP_NAME"
      echo "Set omanix.apps.${safeName}.url in configuration.nix"
      exit 1
    fi

    if [ -d "$DEST" ]; then
      echo "$APP_NAME is already installed at $DEST"
      echo "Run 'omanix uninstall-app ${safeName}' first to reinstall"
      exit 0
    fi

    echo "Downloading $APP_NAME..."
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    if [ "$APP_TYPE" = "dmg" ]; then
      curl -fSL -o "$TMPDIR/app.dmg" "$APP_URL"
      echo "Mounting DMG..."
      hdiutil attach "$TMPDIR/app.dmg" -mountpoint "$TMPDIR/mnt" -nobrowse -quiet
      # Find .app in DMG (could be at root or in a subdirectory)
      APP_SRC=$(find "$TMPDIR/mnt" -name "*.app" -maxdepth 2 | head -1)
      if [ -z "$APP_SRC" ]; then
        echo "ERROR: No .app found in DMG"
        hdiutil detach "$TMPDIR/mnt" -quiet
        exit 1
      fi
      echo "Installing to $DEST..."
      cp -R "$APP_SRC" "$DEST"
      hdiutil detach "$TMPDIR/mnt" -quiet
    elif [ "$APP_TYPE" = "zip" ]; then
      curl -fSL -o "$TMPDIR/app.zip" "$APP_URL"
      unzip -q "$TMPDIR/app.zip" -d "$TMPDIR/"
      APP_SRC=$(find "$TMPDIR" -name "*.app" -maxdepth 2 | head -1)
      if [ -z "$APP_SRC" ]; then
        echo "ERROR: No .app found in zip"
        exit 1
      fi
      echo "Installing to $DEST..."
      cp -R "$APP_SRC" "$DEST"
    else
      echo "ERROR: Unknown type '$APP_TYPE' (expected 'dmg' or 'zip')"
      exit 1
    fi

    echo "✓ $APP_NAME installed to $DEST"
  '';

  uninstallScript = pkgs.writeShellScript "uninstall-${safeName}" ''
    set -euo pipefail

    APP_NAME="${name}"
    DEST="${appPath}"

    if [ ! -d "$DEST" ]; then
      echo "$APP_NAME is not installed"
      exit 0
    fi

    echo "Removing $APP_NAME from $DEST..."
    rm -rf "$DEST"
    echo "✓ $APP_NAME uninstalled"
  '';

in {
  inherit installScript uninstallScript;

  # Convenience: the derivation for home.file
  installFile = {
    "local/bin/install-${safeName}" = {
      source = installScript;
      executable = true;
    };
    "local/bin/uninstall-${safeName}" = {
      source = uninstallScript;
      executable = true;
    };
  };
}
