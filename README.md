# Omanix

> **Omarchy for macOS, managed by Nix.**

Omanix is a declarative desktop environment for Apple Silicon and Intel Macs. It installs **Omarchy 4** alongside macOS with **Nix**, giving you reproducible system state, atomic upgrades, and instant rollbacks — without Asahi Linux or virtual machines.

<p align="center">
  <img src="hero.jpg" alt="Omanix on Apple Silicon MacBook: the desktop flowing around the display notch" width="860" />
</p>

<p align="center">
  <a href="https://github.com/nowarelabs/omanix"><img alt="macOS 12+" src="https://img.shields.io/badge/macOS-12%2B-black?logo=apple&logoColor=white" /></a>
  <a href="https://nixos.org"><img alt="Built with Nix" src="https://img.shields.io/badge/Built%20with-Nix-5277C3?logo=nixos&logoColor=white" /></a>
  <a href="https://github.com/nowarelabs/omanix"><img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-Supported-success" /></a>
  <a href="./LICENSE"><img alt="License: ISC" src="https://img.shields.io/badge/License-ISC-blue.svg" /></a>
</p>

---

## Table of Contents

- [Features](#features)
- [System Requirements](#system-requirements)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [One-Command Install](#one-command-install)
  - [What the Installer Does](#what-the-installer-does)
- [After Install](#after-install)
- [Usage](#usage)
  - [Update & Rollback](#update--rollback)
  - [Customize Your Config](#customize-your-config)
  - [Example Configuration](#example-configuration)
  - [Install Your Own Plugins](#install-your-own-plugins)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Advanced](#advanced)
- [What's Included](#whats-included)
- [Omanix vs. Original Omarchy](#omanix-vs-original-omarchy)
- [Known Limitations](#known-limitations)
- [Contributing](#contributing)
- [License](#license)
- [Support](#support)
- [Acknowledgements](#acknowledgements)

---

## Features

- **One command to install** — No prerequisites. Nix is installed automatically.
- **Works on any Mac** — Apple Silicon (M1/M2/M3/M4) and Intel, running macOS 12+.
- **Reproducible everywhere** — Same `flake.nix` on your laptop and teammates' machines — identical desktop.
- **Atomic upgrades & rollbacks** — `omanix rebuild --rollback` undoes a bad update in seconds.
- **Full declarative config** — Desktop, packages, shell, and plugins defined in one file.
- **No package search needed** — Pre-curated package set optimized for Apple Silicon.

## System Requirements

| Feature      | Requirement                                                 |
| ------------ | ----------------------------------------------------------- |
| OS           | macOS 12 (Monterey) or later                                |
| Architecture | Apple Silicon (`aarch64-darwin`) or Intel (`x86_64-darwin`) |
| Storage      | 10 GB minimum · 50 GB recommended                           |
| RAM          | 4 GB minimum · 8 GB recommended for development             |
| Network      | Required for initial install and updates                    |

---

## Installation

### Prerequisites

- **macOS 12 or later** (any Apple Silicon or Intel Mac)
- **At least 10 GB free space** for the Nix store
- **Administrator password** (for initial Nix installation)

### One-Command Install

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --determinate && \
  nix run github:nowarelabs/omanix#install
```

That's it. Expect **5–15 minutes**, depending on internet speed and whether binaries are cached.

The installer will:

1. Install the Determinate Systems Nix installer (if Nix is not already present)
2. Clone the Omanix flake
3. Prompt for your username, hostname, and password
4. Build your system configuration
5. Activate Omarchy and reboot into the desktop

### What the Installer Does

- [x] Installs Nix (via Determinate Systems installer)
- [x] Creates a user account with sudo access
- [x] Sets up `nix-darwin` for macOS system management
- [x] Installs `home-manager` for user dotfiles and shell config
- [x] Installs Omarchy (Hyprland, Quickshell, plugins, themes)
- [x] Configures system settings (firewall, keyboard, trackpad, etc.)
- [x] Enables automatic updates (configurable)

---

## After Install

### 1. Log In

The installer creates a user account. Log in with the username and password you provided during setup.

### 2. Access the Omarchy Menu

Press `Super` (⌘ / Windows key) to open the Omarchy menu. From there you can:

- Launch applications
- Switch workspaces
- Adjust audio, brightness, network
- Access system settings

---

## Usage

### Update & Rollback

Update packages and rebuild the system:

```bash
omanix rebuild
```

Rollback a bad update:

```bash
omanix rebuild --rollback
```

List available generations (previous configurations):

```bash
omanix generations
```

### Customize Your Config

Your system is defined in `~/.config/omanix/flake.nix`. Edit it to:

- Add / remove packages
- Change shell configuration
- Customize Omarchy plugins
- Tweak macOS settings (dock, trackpad, keyboard, etc.)

Then rebuild:

```bash
omanix rebuild
```

### Example Configuration

```nix
# ~/.config/omanix/flake.nix
{
  description = "My Omanix System";

  inputs = {
    omanix.url = "github:nowarelabs/omanix";
    nixpkgs.follows = "omanix.nixpkgs";
  };

  outputs = { self, omanix, nixpkgs }: {
    darwinConfigurations.default = omanix.lib.mkDarwinSystem {
      system = "aarch64-darwin"; # or x86_64-darwin for Intel
      hostname = "my-mac";
      username = "yourname";

      # Add extra packages
      extraPackages = with nixpkgs.legacyPackages.aarch64-darwin; [
        nodejs
        rustc
        go
        postgresql
      ];

      # Customize home-manager
      homeManagerConfig = { pkgs, ... }: {
        programs.git.enable = true;
        programs.git.userEmail = "you@example.com";
        programs.git.userName = "Your Name";

        # Add shell aliases
        programs.bash.shellAliases = {
          ll = "ls -lah";
          dev = "cd ~/projects";
        };
      };

      # Customize Omarchy
      omarchy = {
        plugins.enabled = [
          "omarchy.clock"
          "omarchy.audio"
          "omarchy.network"
          "my-custom-plugin"
        ];

        bar = {
          position = "top";
          transparent = false;
          layout = {
            left = [ "omarchy.menu" "omarchy.workspaces" ];
            center = [ "omarchy.clock" ];
            right = [ "omarchy.audio" "omarchy.battery" ];
          };
        };
      };
    };
  };
}
```

### Install Your Own Plugins

Omarchy plugins are git repositories. Add them to your flake:

```nix
# ~/.config/omanix/flake.nix
homeManagerConfig = { pkgs, ... }: {
  home.activation.omarchyPlugins = ''
    mkdir -p ~/.config/omarchy/plugins
    cd ~/.config/omarchy/plugins

    # Clone a plugin (must have manifest.json at root)
    git clone https://github.com/your-org/omarchy-weather-plugin.git
    git clone https://github.com/your-org/omarchy-custom-bar.git
  '';
}
```

Then reference them in your Omarchy config as shown above.

---

## Troubleshooting

<details>
<summary><strong><code>Command not found: omanix</code></strong></summary>

Nix wasn't installed properly, or the `PATH` is stale. Reload your shell:

```bash
exec $SHELL
```

If that doesn't work, check that Nix is installed:

```bash
which nix
nix --version
```

If `nix` is not found, re-run the installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --determinate
```

</details>

<details>
<summary><strong><code>Permission denied</code> during rebuild</strong></summary>

`omanix rebuild` uses `sudo` internally. If you're not in the `wheel` group, add yourself:

```bash
sudo dseditgroup -o edit -a $(whoami) -t user wheel
```

Then log out and log back in.

</details>

<details>
<summary><strong><code>Flake is outdated</code> or build failures</strong></summary>

Update Nix and the flake:

```bash
nix flake update ~/.config/omanix/flake.nix
omanix rebuild
```

</details>

<details>
<summary><strong>Rollback after a bad update</strong></summary>

If your system doesn't boot or behaves badly:

```bash
omanix rebuild --rollback
```

This reverts to the last working generation. No loss of data; your home directory is unchanged.

</details>

<details>
<summary><strong><code>Disk full</code> errors</strong></summary>

The Nix store can grow large. Clean up old generations:

```bash
nix-collect-garbage -d
```

This removes build artifacts and old system generations (keeping the last 3 by default).

</details>

<details>
<summary><strong>SSH stopped working</strong></summary>

`nix-darwin` ships with SSH enabled by default. To disable it:

```nix
# In your ~/.config/omanix/flake.nix
services.openssh.enable = false;
```

```bash
omanix rebuild
```

To re-enable and add your public keys:

```nix
services.openssh.enable = true;
services.openssh.authorizedKeysFiles = [ "~/.ssh/authorized_keys" ];
```

```bash
omanix rebuild
```

Then copy your key:

```bash
cat ~/.ssh/id_ed25519.pub | ssh user@host "cat >> ~/.ssh/authorized_keys"
```

</details>

---

## Uninstall

To remove Omanix and return to stock macOS:

```bash
# 1. Remove Nix
/nix/nix-installer uninstall

# 2. Remove Omarchy user (optional)
sudo sysadminctl -deleteUser omanix

# 3. Reboot
sudo reboot
```

> Omanix makes no permanent changes to macOS. All system state lives in `/nix/store` and Nix configuration. Uninstalling Nix removes everything.

---

## Advanced

### Use Your Own Flake

Instead of the default configuration, use your own git repo:

```bash
nix run github:nowarelabs/omanix#install -- --flake github:your-org/your-omarchy-config
```

This clones your flake and uses it instead of the default. Useful for teams.

### Pin Versions for Reproducibility

Lock specific package versions in your flake:

```nix
inputs = {
  omanix.url = "github:nowarelabs/omanix/v1.0.0"; # Tag or commit hash
  nixpkgs.follows = "omanix.nixpkgs";
};
```

Update when you're ready:

```bash
nix flake update ~/.config/omanix/flake.nix
omanix rebuild
```

### Develop Omarchy Plugins

The flake includes a dev environment:

```bash
cd ~/.local/share/omanix
nix develop

# Now you have Quickshell, QML tools, and dependencies available
```

Build a plugin and test it:

```bash
# Your plugin goes in ~/.config/omarchy/plugins/<id>/
# Reload plugins without a full rebuild
omarchy-shell shell rescanPlugins
```

### Use a Remote Flake as a Baseline

Fork or wrap the official Omanix flake and layer your changes:

```nix
inputs = {
  omanix.url = "github:nowarelabs/omanix";
  nixpkgs.follows = "omanix.nixpkgs";
};

outputs = { self, omanix, nixpkgs }: {
  darwinConfigurations.default =
    (omanix.darwinConfigurations."aarch64-darwin").override {
      extraPackages = with nixpkgs.legacyPackages.aarch64-darwin; [
        # Your additions here
      ];
    };
}
```

---

## What's Included

| Category             | Packages                                                                                                      |
| -------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Core**             | Nix (Determinate Systems) + `nix-darwin`, `home-manager`, Omarchy 4 (Hyprland, Quickshell, plugins)           |
| **Desktop**          | Hyprland (Wayland compositor), Quickshell (QML shell), Foot (terminal), Nautilus (file manager), SDDM (login) |
| **Browsers & Media** | Chromium, Firefox, MPV, Imv                                                                                   |
| **Development**      | Neovim + LSPs, Git + `gh`, Docker & Docker Compose, Node.js / Ruby / Python (base), Build tools               |
| **Utilities**        | Fastfetch, FZF, Ripgrep, Bat, EZA, Starship, Tmux, Zoxide                                                     |
| **Shell**            | Zsh (default) or Bash — themed, keybindings, FZF history                                                      |
| **Plugins**          | Clock, Workspaces, Menu, Audio, Network, Bluetooth, Battery, Weather (optional) + custom plugin support       |

> See `flake.nix` for the complete list and pinned versions.

---

## Omanix vs. Original Omarchy

|                     | Original Omarchy (`omarchy-mac`)     | **Omanix**                                |
| ------------------- | ------------------------------------ | ----------------------------------------- |
| **Platform**        | Asahi Linux (Linux on Apple Silicon) | **Native macOS** (no VM / boot partition) |
| **Package manager** | Arch Linux + Pacman + AUR            | **Nix + nix-darwin** (declarative)        |
| **Bootloader**      | m1n1 → u-boot → GRUB                 | **macOS native** (EFI, Apple firmware)    |
| **Filesystem**      | BTRFS with encryption                | **APFS** (native macOS), managed by Nix   |
| **Snapshots**       | Custom BTRFS tools                   | **Nix generations** (built-in rollback)   |
| **Hardware**        | Apple Silicon only                   | **Apple Silicon + Intel**                 |
| Asahi Alarm         | Required                             | **Not required**                          |

Both give you Omarchy — Omanix is the macOS-native version.

---

## Known Limitations

| Limitation           | Details                                                                                               | Workaround                                                     |
| -------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **Wayland on macOS** | Hyprland (Wayland) is not officially supported on macOS. Some advanced Wayland features may not work. | Fall back to macOS Quartz window manager or use an X11 server. |
| **GPU Acceleration** | Apple Silicon GPU drivers are less mature than on Linux. Some 3D apps may be slower.                  | Use CPU rendering or a Linux VM for heavy GPU work.            |
| **System Fonts**     | Not all Linux fonts render identically on macOS.                                                      | Install additional fonts via `extraPackages`.                  |
| **Bluetooth Audio**  | Codec support is limited vs. Linux.                                                                   | Use USB / wired audio for best compatibility.                  |
| **Printing**         | CUPS support is basic on macOS.                                                                       | Use native macOS print dialogs or third-party services.        |

---

## Contributing

Omanix is open source — contributions welcome!

- **Report bugs:** [GitHub Issues](https://github.com/nowarelabs/omanix/issues)
- **Submit fixes:** [GitHub Pull Requests](https://github.com/nowarelabs/omanix/pulls)
- **Discuss features:** [GitHub Discussions](https://github.com/nowarelabs/omanix/discussions)

To hack on Omanix locally:

```bash
git clone https://github.com/nowarelabs/omanix.git ~/.local/share/omanix-dev
cd ~/.local/share/omanix-dev
nix develop

# Make your changes, then rebuild
omanix rebuild --flake .#
```

---

## License

Omanix is licensed under the **ISC License**. See [LICENSE](./LICENSE) for details.

---

## Support

### Community

- **Discord:** Omarchy Community
- **Discussions:** [GitHub Discussions](https://github.com/nowarelabs/omanix/discussions)

### Get Help

- Installation issues → [Troubleshooting](#troubleshooting)
- Configuration help → [Customize Your Config](#customize-your-config)
- Bug reports → [Open an issue](https://github.com/nowarelabs/omanix/issues)

### Sponsor

Omanix is maintained by volunteers. If you enjoy it, consider supporting the project:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/)

_GitHub Sponsors: Coming soon_

---

## Acknowledgements

Omanix builds on the work of:

- [Omarchy](https://omarchy.org) (DHH — original concept and design)
- [nix-darwin](https://github.com/LnL7/nix-darwin) (Luc van Luijn — macOS Nix integration)
- [home-manager](https://github.com/nix-community/home-manager) (Nix community)
- [Determinate Systems](https://determinate.systems) (Nix installer, macOS support)
- [Hyprland](https://hyprland.org) (Wayland compositor)
- [Quickshell](https://quickshell.org) (QML desktop shell)

And thanks to the Nix and macOS communities for feedback and contributions.

---

<p align="center">
  <sub>See <a href="./CHANGELOG.md">CHANGELOG.md</a> for release notes and breaking changes.</sub>
</p>
