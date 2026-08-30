#!/bin/bash
# libexec/install.sh — shared installation logic for Omanix
# Used by both `bin/install` (bootstrap) and `bin/omanix install` (reinstall)
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.omanix}"
HOST="${HOST:-$(scutil --get LocalHostName 2>/dev/null || echo "")}"
USER="${USER:-$(whoami)}"

# --- Logging (works with or without libexec/log.sh) ---
if [[ -f "$FLAKE_DIR/libexec/log.sh" ]]; then
  source "$FLAKE_DIR/libexec/log.sh"
else
  log_info()  { echo "[omanix] $2"; }
  log_error() { echo "[omanix] ERROR: $2" >&2; }
  log_warn()  { echo "[omanix] WARNING: $2"; }
fi

# --- Pre-flight checks ---
install_preflight() {
  echo "Omanix Installer"
  echo "================"
  echo ""

  # Check for macOS
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: Omanix requires macOS."
    exit 1
  fi

  # Check macOS version (need 13+ for SwiftUI features)
  MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
  if [[ "$MACOS_VERSION" -lt 13 ]]; then
    echo "ERROR: macOS 13 (Ventura) or later required. Found: macOS $MACOS_VERSION"
    exit 1
  fi
  echo "macOS $MACOS_VERSION detected"

  # Check for internet connectivity
  echo -n "Checking internet connectivity... "
  if ! curl -sf --max-time 10 https://nixos.org -o /dev/null 2>/dev/null; then
    echo "FAILED"
    echo "ERROR: No internet connection. Omanix requires internet for installation."
    echo "Please connect to the internet and try again."
    exit 1
  fi
  echo "OK"

  # Check available disk space (need ~5GB for Nix store + packages)
  echo -n "Checking disk space... "
  AVAIL_KB=$(df -k / | tail -1 | awk '{print $4}')
  AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
  if [[ "$AVAIL_GB" -lt 5 ]]; then
    echo "WARNING: Only ${AVAIL_GB}GB available. Recommend 5GB+ for Nix store and packages."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Installation cancelled. Free up disk space and try again."
      exit 1
    fi
  else
    echo "OK (${AVAIL_GB}GB available)"
  fi

  # Check for Xcode Command Line Tools
  if ! xcode-select -p &>/dev/null; then
    echo "Xcode Command Line Tools not found."
    echo "Required for building packages and the Omanix Store."
    echo ""
    read -p "Install Xcode Command Line Tools? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Installing Xcode Command Line Tools..."
      echo "A dialog will appear — click Install and wait for it to finish."
      xcode-select --install
      echo ""
      echo "Press any key after installation completes..."
      read -n 1 -s
      # Verify installation
      if ! xcode-select -p &>/dev/null; then
        echo "ERROR: Xcode Command Line Tools still not installed."
        echo "Please install manually: xcode-select --install"
        exit 1
      fi
    else
      echo "WARNING: Some features may not work without Xcode Command Line Tools."
      echo "Install later with: xcode-select --install"
    fi
  else
    echo "Xcode Command Line Tools found"
  fi

  # Check for git
  if ! command -v git &>/dev/null; then
    echo "ERROR: git not found. Install Xcode Command Line Tools: xcode-select --install"
    exit 1
  fi

  # Check for curl
  if ! command -v curl &>/dev/null; then
    echo "ERROR: curl not found"
    exit 1
  fi

  # Check for sudo access (only darwin-rebuild needs it, and only that
  # binary is whitelisted NOPASSWD via /etc/sudoers.d/ after the first
  # install — `sudo -n true` would always fail, so test the real binary).
  if ! sudo -n /run/current-system/sw/bin/darwin-rebuild --help &>/dev/null 2>&1 \
     && ! sudo -n darwin-rebuild --help &>/dev/null 2>&1; then
    echo ""
    echo "Omanix requires sudo access for system configuration."
    echo "You'll be prompted for your password during installation."
    echo ""
    sudo -v || {
      echo "ERROR: sudo access required but not available."
      exit 1
    }
  fi

  echo ""
}

# --- Install Nix if missing ---
install_nix() {
  if command -v nix &>/dev/null; then
    echo "Nix found: $(nix --version)"
  else
    echo "Nix not found. Installing via Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  # Check for Homebrew (optional, but recommended)
  if ! command -v brew &>/dev/null; then
    echo ""
    echo "Homebrew not found (optional)."
    echo "Some packages use Homebrew casks. Install later with:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  else
    echo "Homebrew found"
  fi
  echo ""
}

# --- Clone or update Omanix ---
install_clone() {
  if [[ -d "$FLAKE_DIR/.git" ]]; then
    echo "Omanix already installed at $FLAKE_DIR"
    return 1  # Signal: already exists
  fi

  echo "Cloning Omanix to $FLAKE_DIR..."
  git clone https://github.com/nowarelabs/omanix.git "$FLAKE_DIR"
  return 0  # Signal: freshly cloned
}

# --- Configure hostname and username ---
install_configure() {
  cd "$FLAKE_DIR"

  # Read current values
  local current_host current_user
  current_host=$(grep -o 'omanix.host = "[^"]*"' configuration.nix 2>/dev/null | cut -d'"' -f2 || echo "")
  current_user=$(grep -o 'omanix.user = "[^"]*"' configuration.nix 2>/dev/null | cut -d'"' -f2 || echo "")

  # Prompt if not set
  if [[ -z "$current_host" ]]; then
    local default_host
    default_host=$(scutil --get LocalHostName 2>/dev/null || echo "my-mac")
    read -p "Hostname [$default_host]: " current_host
    current_host="${current_host:-$default_host}"
  fi

  if [[ -z "$current_user" ]]; then
    local default_user
    default_user=$(whoami)
    read -p "Username [$default_user]: " current_user
    current_user="${current_user:-$default_user}"
  fi

  # Update configuration.nix
  sed -i '' "s/omanix.host = \".*\"/omanix.host = \"$current_host\"/" configuration.nix
  sed -i '' "s/omanix.user = \".*\"/omanix.user = \"$current_user\"/" configuration.nix
  echo "Configuration updated: host=$current_host user=$current_user"

  HOST="$current_host"
}

# --- Build system ---
install_build() {
  echo ""
  echo "Building Omanix..."
  sudo darwin-rebuild switch --flake "$FLAKE_DIR#$HOST" --show-trace
  echo ""
  echo "Omanix installed! Reboot recommended."
  echo "  omanix open    — open Omanix Store"
  echo "  omanix rebuild — apply future changes"
  echo "  omanix update  — update to latest version"
}

# --- Install (preflight, nix, configure, build — clone handled by caller) ---
install() {
  install_preflight
  install_nix
  install_configure
  install_build
}
