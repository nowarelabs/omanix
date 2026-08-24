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
  - [Example Configuration — Distro Clone](#example-configuration--distro-clone-the-only-blessed-path)
  - [Add Apps, Widgets & Your Own Swift Apps — Not Bash Plugins](#add-apps-widgets--your-own-swift-apps--not-bash-plugins)
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

> **Hard lines & architecture:** See [`docs/principles.md`](./docs/principles.md) (invariants), [`docs/philosophies.md`](./docs/philosophies.md) (why), [`docs/conventions.md`](./docs/conventions.md) (how + folder structure). README is the user-facing summary; docs are the source of truth.

---

## Features

- **One command to install** — No prerequisites. Nix is installed automatically.
- **Works on any Mac** — Apple Silicon (M1/M2/M3/M4) and Intel, running macOS 12+.
- **Reproducible everywhere** — Same `flake.nix` on your laptop and teammates' machines — identical desktop.
- **Atomic upgrades & rollbacks** — `omanix rebuild --rollback` undoes a bad update in seconds.
- **Full declarative config** — Desktop, packages, shell, and widgets defined in one file. No `.toml`/`.tpl`/`.config` hand-edits — use Nix options (`omanix.theme`, `desktop.aerospace.*`).
- **Curated, not closed** — Pre-curated defaults, but `search.nixos.org` + `brew` are the catalog. `omanix add <name>` routes to `nixpkgs` (`pkgs`) or Homebrew (`casks`/`brews`) declaratively — no custom re-packaging if either already ships.
- **Nix-native widgets & apps** — Community pomodoro etc. are `launchd`/`Swift` derivations (`omanix.widgets.pomodoro.enable` via `lib/mkWidget`/`lib/mkApp`, SDK + auto-wrap), not bash — they appear as Mac apps and vanish on removal.
- **Omanix Store GUI** — App Store-like SwiftUI app (GTK on future Linux), itself a `omanix.widgets.store` widget. Browse `search.nixos.org`+`brew`, one-click `Install` via `omanix add`, toggle `omanix.widgets`/`omanix.theme`, tweak OS settings — no terminal for green users (`Super → Omanix Store` or `omanix store`).
- **AI-agent-ready** — `skills/omanix/SKILL.md` typed contract (`lib/mkWidget`/`lib/mkApp` + `${theme.colors}`) with `statix`/`nix fmt` lint, `overlays/` preview (`omanix rebuild --preview` → `sketchybar --reload`/`launchctl`) then commit (`omanix add` → `flake.lock`, generation). Claude Code writes Nix, it just appears themed and rollbackable.
- **Pristine uninstall** — `omanix uninstall` removes Nix, `launchd` agents, Swift apps, and the casks it added. Leaves the Mac clean (see `docs/principles.md:12`).

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
- [x] Installs Omarchy taste (Hyprland `*.lua` compiles to AeroSpace TOML via `lib/hypr-to-aerospace.nix`, Quickshell tokens to SketchyBar via `lib/themed.nix`, themes as Nix derivations)
- [x] Configures system settings (firewall, keyboard, trackpad, etc.) via macOS-native `system.defaults` + `security.pam` (Touch ID)
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

### Customize Your Config — One File, No Raw `.toml`/`.tpl`

Your system is defined in `~/.config/omanix/flake.nix` (distro — see `docs/principles.md:1`). Edit it to:

- Add / remove packages and apps (`omanix add ripgrep` auto-edits this file for you; under the hood `nixpkgs` vs `homebrew` per `docs/conventions.md:6` — no re-packaging if either already ships)
- Change shell configuration (`programs.zsh`, `programs.git`)
- Enable Nix-native widgets/apps (`omanix.widgets.pomodoro.enable = true` via `lib/mkWidget`/`lib/mkApp`) — not `omarchy.plugins.*` or git clones
- Tweak macOS settings (`system.defaults.dock`, `security.pam.services.sudo_local.touchIdAuth`, `desktop.aerospace.*`, `omanix.theme` / `omanix.bar.*` — never raw `aerospace.toml`/`colors.toml`/`sketchybarrc`; see `docs/principles.md:3`)

Then rebuild:

```bash
omanix rebuild
```

### Example Configuration — One File for Green Users, Scales to Complexity

Your Mac _is_ `~/.config/omanix/configuration.nix` — Omanix, not Omarchy spec. You set `omanix.*` (own brand) in one commented file, `lib/themed.nix` renders, and `hosts/` scales later. Pinning is `flake.lock` (`config/flake.nix:5` style). Future Linux reuses the same `omanix.theme`/`omanix.widgets`.

```nix
# ~/.config/omanix/flake.nix — ~30 lines, you rarely edit this (shown for completeness)
{
  description = "My Omanix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/917fec990948658ef1ccd07cef2a1ef060786846"; # pinned rev
    nix-darwin.url = "github:LnL7/nix-darwin/52d061516108769656a8bd9c6e811c677ec5b462";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/27b93804fbef1544cb07718d3f0a451f4c4cd6c0";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ self, nixpkgs, nix-darwin, home-manager }:
    let lib = import ./lib/mkSystem.nix { inherit inputs; }; # branches darwinSystem vs future nixosSystem
    in {
      darwinConfigurations."my-mac" = lib.mkSystem {
        system = "aarch64-darwin"; # or x86_64-darwin, or x86_64-linux for future linux
        modules = [ ./configuration.nix ./hosts/my-mac/default.nix ];
      };
    };
}
```

```nix
# ~/.config/omanix/configuration.nix — ⭐ the file you edit (beginner-friendly, commented, scalable)
{ pkgs, ... }: {
  # Who & where — green users change just these three
  omanix.host = "my-mac";
  omanix.user = "yourname";
  omanix.theme = "tokyo-night"; # lib/themed.nix renders themes/*/colors.toml + default/themed/*.tpl — never raw .toml

  # Widgets/apps — Omanix, not Omarchy spec. Appear as Mac apps, vanish on false.
  omanix.widgets.pomodoro.enable = true; # SketchyBar item + launchd timer (linux: systemd) + optional /Applications/Pomodoro.app
  omanix.widgets.clock.enable = true;
  # omanix.widgets.calendar.enable = true;

  # Packages — `search.nixos.org` + `brew` are the registry; no custom packaging if either ships
  environment.systemPackages = with pkgs; [ nodejs ripgrep starship ]; # nixpkgs
  homebrew.casks = [ "google-chrome" "visual-studio-code" ]; # signed .app only
  homebrew.brews = []; # only if brew search finds what nix misses

  # Desktop — typed, never raw .toml/.tpl; picks aerospace/sketchybar on mac, hyprland/quickshell on future linux
  # omanix.desktop.aerospace.gaps.inner = 8;
  # omanix.bar.position = "top";
}
```

```nix
# ~/.config/omanix/hosts/my-mac/default.nix — only when you need a second machine (optional)
{ ... }: {
  # imports ../configuration.nix + ../hosts/common.nix automatically — just override host
  # networking.hostName = "work-mac";
}
```

After editing either file: `omanix rebuild` (→ `sudo darwin-rebuild switch --flake ~/.config/omanix#my-mac`). New to Nix? No need to learn flakes day one — `omanix add ripgrep` edits `configuration.nix` for you.

### Add Apps, Widgets & Your Own Swift Apps — Not Bash Plugins

Omarchy lets anyone `omarchy-plugin-add` a bash repo and it appears as a widget. Omanix keeps the _capability_ but replaces the _mechanism_ with Nix derivations: a SketchyBar widget, a `launchd` agent, or a Swift/SwiftUI `.app` (see `docs/principles.md:10`). Both paths are supported — prescriptive SDK and auto-wrap.

**Fast path — `omanix add` routing (primary UX):**

```bash
# nixpkgs → pkgs (no custom packaging if search.nixos.org has it)
omanix add ripgrep          # edits flake.nix → environment.systemPackages += pkgs.ripgrep → rebuild
omanix search ripgrep       # nix search nixpkgs ripgrep && brew search ripgrep

# brew cask/brew → homebrew (only for signed .app where nix would break signing)
omanix add google-chrome    # → homebrew.casks += [ "google-chrome" ]

# Swift widget/app — auto-wrap a single Swift repo (no flake required)
omanix add github:your-org/pomodoro-swift   # detects Sources/*.swift, builds via swift build/xcodebuild, generates launchd plist + SketchyBar item
```

**SDK path — publish a widget flake (for sharing):**

```nix
# Your widget flake exposes omanixWidgets.pomodoro via lib/mkWidget/mkApp
# User then enables it without touching .toml/.tpl/.config:
# inputs.pomodoro.url = "github:your-org/pomodoro-omanix";
# omanix.widgets.pomodoro.enable = true;
# → SketchyBar item + launchd timer at 60s + optional /Applications/Pomodoro.app (all in /nix/store)
```

Remove is symmetric: `omanix remove ripgrep` / `omanix remove pomodoro` edits `flake.nix` and rebuilds; `omanix rebuild --rollback` restores, and `omanix uninstall` is full pristine (including casks). Never `git clone` into `~/.config/omarchy/plugins` — `home.activation` git clones are linted as failures.

### Omanix Store — GUI for Green Users (Itself a Widget, Enabled by Default)

Don't know `omanix` commands? Open `Super → Omanix Store` (or `open -a "Omanix Store"` / `omanix store`, `docs/principles.md:14`) — enabled by default (`omanix.widgets.store.enable = true` in `configuration.nix`, disable with `false` + rebuild). It's a SwiftUI app on macOS (GTK on future Linux) built via `lib/mkApp` — itself `omanix.widgets.store`:

- Browse Nix (`search.nixos.org` cached) + brew (`brew search`) + `omanix.widgets` gallery + `omanix.theme` picker
- One-click `Install`/`Remove` → calls `omanix add` helpers, shows `configuration.nix` diff preview, `nix flake check` dry, then `omanix rebuild` with progress + `Rollback` button
- Toggle `omanix.widgets.pomodoro` etc., tweak `system.defaults` sliders — all without opening a terminal or `.nix` file

Power users can ignore it; green users need never open a terminal.

### AI Agents — Tell Claude to Make It Appear (Same Delight, Mac-Native)

Omarchy pomodoro magic: _"make pomodoro, it just appears themed."_ Omanix keeps the delight via `skills/omanix/SKILL.md` (`docs/principles.md:15`, `docs/conventions.md:15`):

1. **User:** _"Hey Claude, make me a pomodoro timer"_
2. **Agent drafts + lints:** reads `SKILL.md` (typed `lib/mkWidget { name, sketchybarConfig, launchdConfig, swiftSrc, theme, dependencies }`), writes `~/.config/omanix/overlays/pomodoro/{default.nix, Sources/ContentView.swift}` (`overlays/` git-ignored), runs `nix fmt`, `statix check`, `nix-instantiate --parse` — linters are auto-installed by `bin/omanix install` (`statix`+`nixfmt`+`nixd` in PATH)
3. **Preview (instant, impure, no generation):** `omanix rebuild --preview` — evaluates `overlays/*` impurely, builds `/nix/store/...-pomodoro` with `${theme.colors.accent}` theme-injected, hot-reloads `sketchybar --reload` + `launchctl load` (mac) / `quickshell ipc` + `systemctl` (future Linux) — widget appears themed
4. **Commit _or_ keep impure (you choose, approved):** pure `omanix add pomodoro --from-overlay` moves it to `inputs.pomodoro` + `omanix.widgets.pomodoro.enable` in `configuration.nix`, `nix flake lock --update-input`, `nix flake check`, `omanix rebuild` (new generation, Store-visible) and clears `overlays/`; _or_ keep `overlays/pomodoro/` permanent impure (no lock, `rm -rf` to remove, fast for AI experiments). Future Linux picks `widget.qml` + `systemd` branch automatically — same skill, cross-platform.

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

## Uninstall — Full Pristine

To remove Omanix and return to a pristine macOS (including the apps Omanix added):

```bash
# 1. Remove Omanix-added casks/brews first (optional — also happens on `cleanup = "uninstall"` next rebuild, but this is immediate)
# Omanix tracks them in flake.nix homebrew.casks/brews; removing the flake + this cleans them
# (or: omanix remove google-chrome && omanix rebuild) for selective removal

# 2. Remove Nix (removes /nix/store, /nix/var/nix/profiles, launchd plists, Swift app symlinks in /Applications)
 /nix/nix-installer uninstall

# 3. Remove the distro clone
rm -rf ~/.config/omanix

# 4. Remove Omarchy user (optional — Omanix normally uses your primary Mac user)
sudo sysadminctl -deleteUser omanix 2>/dev/null || true

# 5. Reboot
sudo reboot
```

> **Guarantee:** No `~/Library/LaunchAgents` plist, no `~/.config/hypr` residue, no `/Applications/Pomodoro.app` symlink, no Omanix-added `google-chrome` cask remains — they were all `launchd.user.agents` / `homebrew` / `/nix/store` symlinks (see `docs/principles.md:12` and `tests/pristine`). Core macOS (APFS, FileVault, `/Applications` pre-Omanix) is untouched. Verified by `tests/pristine: switch → add ripgrep → add google-chrome → uninstall`.

---

## Advanced

### Use Your Own Flake (Team Fork) — Distro, Not Library

Omanix _is_ the flake you edit (`~/.config/omanix/flake.nix`), not a library you import. For teams, fork `nowarelabs/omanix` and make the fork the distro:

```bash
# installer with your fork (one-command, still no prerequisites)
nix run github:nowarelabs/omanix#install -- --repo your-org/omanix
# or manually
git clone https://github.com/your-org/omanix ~/.config/omanix
cd ~/.config/omanix && omanix rebuild
```

Teammates clone the same fork rev and get the identical bar, AeroSpace bindings, theme, and widgets (`flake.lock` is the contract).

### Pin Versions for Reproducibility

Pinning is `flake.lock` (rev like `917fec990948658...` as in `config/flake.nix:5`), not a floating `inputs.omanix.url`:

```bash
# lock all inputs atomically
nix flake lock --update-input nixpkgs     # or
nix flake update ~/.config/omanix         # update all
omanix rebuild
# history: git log ~/.config/omanix/flake.lock + system.configurationRevision = self.rev
```

To stay on a tag, `git checkout v1.0.0` in `~/.config/omanix` and rebuild — the rev is what `omanix generations` shows.

### Develop Widgets & Swift Apps — Not Bash Plugins

The flake includes a dev shell with the _mac-native_ toolchain (no Quickshell QML at runtime):

```bash
cd ~/.config/omanix   # or ~/.local/share/omanix for hack
nix develop
# now: aerospace, sketchybar, jq, swift, xcodebuild, lib/mkWidget helpers
```

Create a widget/app with the SDK (Both paths):

```bash
# 1. SDK path — prescriptive flake
mkdir -p modules/widgets && $EDITOR modules/widgets/pomodoro.nix
# use lib/mkWidget { name, sketchybarConfig, launchdConfig } or lib/mkApp { swiftSrc, bundleId }

# 2. Auto-wrap path — single Swift file (AI-generated)
omanix add github:your-org/pomodoro-swift   # detects Sources/*.swift, builds, generates launchd + SketchyBar item
omanix rebuild
# appears as /Applications/Pomodoro.app + SketchyBar item; remove with omanix remove pomodoro
```

No `~/.config/omarchy/plugins/<id>/` git clones, no `omarchy-shell shell rescanPlugins`. Widgets are `omanix.widgets.*.enable` booleans.

### Use a Remote Flake as a Baseline — Branch, Not Wrap

Don't wrap via `(omanix.darwinConfigurations."aarch64-darwin").override`. Fork and branch:

```bash
git remote add upstream https://github.com/nowarelabs/omanix
git fetch upstream && git merge upstream/main   # pull upstream taste
# resolve conflicts in lib/themed.nix / modules/desktop — keep your flake.nix edits
omanix rebuild
```

Your `~/.config/omanix/flake.nix` is the baseline; upstream sync is a normal `git merge` of the distro, not a library input.

---

## What's Included

| Category             | Packages                                                                                                                                                                                                                     |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Core**             | Nix (Determinate Systems) + `nix-darwin`, `home-manager`, Omarchy 4 taste (Hyprland `*.lua` compiles to AeroSpace via `lib/hypr-to-aerospace.nix`, Quickshell tokens to SketchyBar via `lib/themed.nix`)                     |
| **Desktop**          | AeroSpace (tiling, was Hyprland) + SketchyBar (was Quickshell, bar flows around notch) + `loginwindow` + Touch ID (was SDDM/Plymouth), Ghostty/Foot (terminal), Finder integration (was Nautilus), `launchd` (was `systemd`) |
| **Widgets / Apps**   | Clock, Workspaces, Menu, Audio, Network, Bluetooth, Battery, Weather + custom Nix-native widgets/apps (`launchd` agents + Swift/SwiftUI `.app` via `lib/mkWidget` / `lib/mkApp`, SDK + auto-wrap, not bash)                  |
| **Browsers & Media** | Chromium, Firefox, MPV, Imv                                                                                                                                                                                                  |
| **Development**      | Neovim + LSPs, Git + `gh`, Docker & Docker Compose, Node.js / Ruby / Python (base), Build tools                                                                                                                              |
| **Utilities**        | Fastfetch, FZF, Ripgrep, Bat, EZA, Starship, Tmux, Zoxide                                                                                                                                                                    |
| **Shell**            | Zsh (default) or Bash — themed, keybindings, FZF history                                                                                                                                                                     |

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

| Limitation                  | Details                                                                                                                                                                                                                 | Workaround                                                                                       |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **Hyprland → AeroSpace**    | Hyprland/Wayland does not run on macOS. `default/hypr/*.lua` compiles to AeroSpace TOML via `lib/hypr-to-aerospace.nix` at build time — no Wayland layer needed. Some `windowrulev2`/gaps have no AeroSpace equivalent. | Add a `desktop.aerospace.*` Nix option (don't edit raw `aerospace.toml`). See `docs/porting.md`. |
| **Quickshell → SketchyBar** | Quickshell QML does not run on Darwin. Tokens from `shell/` + `themes/*/colors.toml` render to SketchyBar via `lib/themed.nix`.                                                                                         | Use `omanix.widgets.*.enable` or `lib/mkWidget`; don't write raw SketchyBar config.              |
| **System Fonts**            | Not all Linux fonts render identically on macOS.                                                                                                                                                                        | Install via `fonts.packages` (`ttf-jetbrains-mono-nerd`) or `environment.systemPackages`.        |
| **Bluetooth Audio**         | Codec support is limited vs. Linux.                                                                                                                                                                                     | Use USB / wired audio for best compatibility.                                                    |

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
