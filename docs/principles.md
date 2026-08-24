# Omanix Principles — Hard Lines

These are invariants. If a change violates a principle, the change is wrong, not the principle. Principles are ordered by precedence; higher beats lower in conflict.

---

## 1. Distro, Not Library

Omanix is the user's flake. The one-command installer clones `github:nowarelabs/omanix` to `~/.config/omanix` and the user edits that flake in place. `omanix rebuild` is `darwin-rebuild switch --flake ~/.config/omanix#<hostname>`.

We do **not** ship as `inputs.omanix.lib.mkDarwinSystem` library. The Approved decision (Distro — clone & edit) exists because Omarchy's power is a file you edit and reload. Nix purity is preserved via `flake.lock`; composability is preserved via `inputs` the *user* adds inside their distro flake.

**Consequence:** `flake.nix` owns `darwinConfigurations.<hostname>`. User owns the file. We own the defaults inside `modules/`. Upgrades are `nix flake update` + `omanix rebuild`.

---

## 2. Native Mapping Over Emulation — No VM

macOS cannot run Hyprland / SDDM / Wayland natively. Hard line: **we do not hide a Linux VM**. (Approved: Native mapping AeroSpace/SketchyBar.)

- **Hyprland → AeroSpace:** `config/hypr/*.lua` and `default/hypr/*.lua` are source of truth but compile at build time to AeroSpace TOML via `lib/hypr-to-aerospace.nix`. No `hyprctl` at runtime; shims call `aerospace`.
- **Quickshell → SketchyBar:** `shell/` QML tokens drive SketchyBar via `modules/desktop/sketchybar.nix`.
- **SDDM → loginwindow:** Replaced by `system.defaults.loginwindow` + `security.pam` (Touch ID).

If a feature cannot be mapped natively, we cut it or redesign for Quartz — we do not smuggle a VM.

---

## 3. Build-Time Purity, No Raw Config — Never Touch .toml/.tpl/.config

Approved: Build-time (Nix-pure). Extended hard line: **the user never edits `.toml`, `.tpl`, or raw `~/.config` files to make Omanix work.**

- **Themes:** `themes/*/colors.toml` + `default/themed/*.tpl` are *internal build inputs*. The user sets `omanix.theme = "tokyo-night"` (a Nix string enum, own brand — not `omarchy.theme` spec) and Nix renders via `lib/themed.nix`. There is no `omarchy-theme-set` mutating `~/.config`.
- **AeroSpace/SketchyBar:** The user sets `omanix.bar.position = "top"` or `omanix.desktop.aerospace.gaps = 8` as Nix options. They never edit `aerospace.toml` or `sketchybarrc` by hand. Raw `xdg.configFile."aerospace/aerospace.toml".text` is a privileged escape hatch, not the normal path, and is linted.
- **Hyprland lua:** `config/hypr/*.lua` is vendored read-only. User overrides are `homeManagerConfig = { xdg.configFile... }` only via Nix, not by opening `~/.config/hypr/hyprland.lua`.

**Rationale:** Omarchy plugins are bash-imperative (`omarchy-plugin-add` git clones, writes `manifest.json`, sources scripts). Omanix rejects that model. If you need to go into a file to make it work, the abstraction is incomplete — the fix is a typed Nix option, not documentation telling you to edit a tpl.

Nix generations are the only snapshot mechanism. `omanix generations` / `omanix rebuild --rollback` reads `/nix/var/nix/profiles/system-*`.

---

## 4. Pragmatic Nix + Homebrew, No Re-packaging

Approved: Pragmatic. Hard line extension: **if it is in `search.nixos.org` (nixpkgs) or `brew search` (homebrew), we do not package it ourselves.**

- **Nix owns:** `environment.systemPackages`, `nix-darwin` modules, `home-manager` dotfiles, `launchd` services, `fonts`, CLI tools, language runtimes (not `mise`), and all Omarchy theming. If `nixpkgs` has a working `aarch64-darwin` build, you use it — e.g., `ripgrep`, `starship`, `postgresql_16`, `nodejs_22`, `rustc`.
- **Homebrew owns:** Signed GUI `.app` casks where Nix would break signing/notarization: `google-chrome`, `visual-studio-code`, `slack`, `orbstack`. Managed declaratively via `homebrew.casks`/`brews` with `onActivation.cleanup = "uninstall"` and `upgrade = true` (`config/flake.nix:110-138` pattern).
- **No custom packaging:** Do not create `packages/foo.nix` if `nixpkgs` or `homebrew` already ships it. `packages/` is only for Omanix-specific adapters (e.g., `omarchy-nvim` wrapper, `sketchybar` plugin helpers, Swift widget app bundler). Before adding to `packages/`, you must show `nix search` and `brew search` miss.

This mirrors the daily driver. `omarchy-pkg-*` is deleted; the replacement is `nix flake update` or `omanix add <name>` which routes to the correct owner (see Conventions 6).

---

## 5. Declarative Device, Imperative Home Is a Bug

- No `sudo` inside `home.activation` to create `/var/lib/postgresql`. `system.activationScripts.preActivation` only for dirs that cannot be `launchd` or `users.users`.
- Dotfiles are `home.file` with `backupFileExtension`. No `ln -sf`.
- `mise`, `npm -g`, `pip --user` are not second package managers. Language versions are `nixpkgs` pins (`nodejs_22`, `ruby_3_3`, `python313`).

---

## 6. One Lock File, One Truth

`flake.lock` pins `nixpkgs`, `nix-darwin`, `home-manager`, and every plugin/app input. `917fec99094...` pins as in `config/flake.nix:5`. `nix flake update` is the only updater; `omarchy-update*` is replaced by `omanix update` → `nix flake update ~/.config/omanix && omanix rebuild`.

---

## 7. APFS + Nix Generations — No BTRFS Theater

APFS + FileVault only. No `snapper`, `limine`, `btrfs-migrate`, `factory-reset`. Deleted on Darwin.

---

## 8. Security Is Darwin-Native

`security.pam.services.sudo_local.touchIdAuth = true`, `system.primaryUser`, `users.users.<name>` as in `config/flake.nix:87-93`. No Linux PAM paths. Firewall is `system.defaults` + `networking.applicationFirewall`, not `ufw`.

---

## 9. No New Package Managers

No `pacman`, `yay`, `mise`, `npm -g`/`pipx` as system state. Homebrew is the *only* second manager, and only for casks (Principle 4).

---

## 10. Apps and Widgets Are Nix Derivations, Not Bash Plugins — launchd/plist/Swift

**This replaces Omarchy's bash-plugin model. Approved: Both — SDK + auto-wrap.** Omarchy lets anyone `omarchy-plugin-add` a git repo with `manifest.json` + bash scripts, and it appears as a widget (e.g., AI-generated pomodoro widget). Omanix preserves the *capability* — community widgets/apps that feel like native daily-drive apps — but replaces the *mechanism* and supports both paths:

- **No bash plugins:** `omarchy-plugin-*` (git clone + `manifest.json` + sourced bash) is deleted on Darwin. Bash-imperative plugins that `echo` into `~/.config` or `pkill` at runtime cannot be reasoned about, rolled back, or signed.
- **Nix-native plugins — two paths (Both):**
  1. **Prescriptive SDK:** `lib/mkWidget` / `lib/mkApp` helpers take `{ name, src (Swift), plistConfig, sketchybarConfig }` and return a module. Authors publish a flake with `omanixWidgets.pomodoro` or `packages.pomodoro`.
  2. **Auto-wrap:** `omanix add github:you/pomodoro-swift` with a single `Sources/*.swift` file is auto-wrapped — Omanix detects Swift, builds via `swift build`/`xcodebuild`, generates the `launchd` plist + SketchyBar item without requiring a full SDK flake.
- **UX:** Either way, it may produce any of: a SketchyBar widget (`modules/desktop/sketchybar/plugins/pomodoro.nix`), a `launchd` agent (`launchd.user.agents.pomodoro`), or a **Swift/SwiftUI app** (`packages/pomodoro-app` → `/Applications` via `home.file`). All hashed and added via options.
- **Example — pomodoro:** On Omarchy, `omarchy-plugin-add pomodoro` drops a bash widget. On Omanix, `omanix add pomodoro` adds `inputs.omanix-pomodoro.url = "github:you/pomodoro-omanix"` and `omanix.widgets.pomodoro.enable = true;` — which enables a `launchd` timer + SketchyBar item + optional Swift menubar app (`/Applications/Pomodoro.app`) built by Nix. It appears as if you installed a Mac app, but it is a Nix derivation that disappears on `omanix remove pomodoro && omanix rebuild`.

This gives macOS what you wanted: "on Mac I would have had to install a Mac app for this" — now you do, but the Mac app *is* the Nix plugin, built reproducibly.

---

## 11. Fast, Reliable Add/Remove — nixpkgs/homebrew Are the Registry — Auto `omanix add`

**Approved: Auto `omanix add` is the primary UX. Do not make the user package or search manually.** Help them get applications/packages quickly and remove them quickly and reliably — using the platforms' registries, not our own.

- **Routing (Auto):** `omanix add <name>` (and `omanix remove <name>`) is the canonical path. It checks `search.nixos.org` (`nix search`) first; if found, it edits `flake.nix` to add `pkgs.<name>` to `environment.systemPackages`/`home.packages` and rebuilds. If not in `nixpkgs` but in `brew search` (cask/brew), it adds to `homebrew.casks`/`brews`. If neither, it suggests `omanix add github:...` for Swift/widget auto-wrap or manual input. Manual `flake.nix` editing still works but `omanix add` is how users are taught.
- **No duplicate registry:** We do not keep an `omanix/packages.json` catalog that re-lists nixpkgs/brew. The system *is* the catalog.
- **Reliability:** Adds and removes are declarative edits + `nix flake lock --update-input` + rebuild; we verify with `nix flake check` and `darwin-rebuild check` before switching, so failures do not leave half-state.

---

## 12. Pristine Mac Guarantee — Full Pristine — Uninstall Leaves No Trace

**Approved: Full pristine. If the user stops using Omanix, their Mac is pristine — including casks Omanix added.** All system state lives in `/nix/store`, `/nix/var/nix/profiles`, the flake repo at `~/.config/omanix`, and (for casks) `/Applications` symlinks managed by Homebrew. Uninstall is:

```bash
/nix/nix-installer uninstall
rm -rf ~/.config/omanix
sudo rm /Library/LaunchDaemons/org.nixos.* 2>/dev/null; true
# All homebrew casks/brews added via homebrew.casks/brews are removed because onActivation.cleanup = "uninstall"
```

Because:
- No file is ever `curl | sh` outside Nix (only Determinate installer, itself reversible).
- No `~/Library/LaunchAgents` plist is written outside `launchd.user.agents` (which `nix-darwin` removes on uninstall).
- Homebrew is on `cleanup = "uninstall"`, so `casks` installed by Omanix vanish when the flake is gone and the user runs `brew uninstall` (or we run it during `omanix uninstall`).
- No `~/.config/hypr/*`, `~/.config/sketchybar/*` survives as a hand-edited file — they were store symlinks. After uninstall, `~/.config` is either backed up (`home-manager.backupFileExtension = "backup"`) or restored via `darwin-rebuild` leaving no Omanix residue.
- Swift apps installed as derivations live in `/nix/store` and are symlinked to `/Applications` via activation; uninstall unlinks them.

We track every path we manage so we can delete it. This is tested: `tests/pristine` does `darwin-rebuild switch` → `omanix add google-chrome` → `switch` → `omanix uninstall` and asserts no `/nix`, no `launchd` leftover, no `/Applications/Omanix*`, no Omanix-added casks remain.

---

## 13. Failure Mode Is Rollback, Removal Is Uninstall

Every `add`/`remove`/`update` must be undoable in <30s via `omanix rebuild --rollback` (generations) and fully removable via `omanix uninstall`. If a module would need destructive `/var/lib` migration, it is a manual migration in `docs/migrations.md` with a guard, not an implicit activation.

---

## Architecture That These Principles Demand — Simple for Green Users, Ready for Linux

**Beginner edits one file. Complexity scales, not starts complex.**

```
omanix/                          # distro flake — cloned to ~/.config/omanix (or ~/.local/share/omanix)
├── flake.nix                    # 30 lines you can read: pinned inputs + mkSystem helper → darwinConfigurations + future nixosConfigurations
├── flake.lock
├── configuration.nix            # ⭐ THE file you edit: omanix.host, omanix.user, omanix.theme, omanix.widgets.*, packages, casks — commented for green users
├── home.nix                     # your dotfiles (zsh, git, starship) — optional; most stay in configuration.nix
├── hosts/                       # scalable: one folder per machine, all import ../configuration.nix
│   ├── my-mac/
│   │   └── default.nix          # thin overlay: { networking.hostName = "my-mac"; } + extra host-only pkgs
│   ├── work-mac/
│   │   └── default.nix          # second mac — same theme/widgets, different host
│   └── common.nix               # shared between darwin + future linux (theme, widgets, add/remove logic)
├── modules/
│   ├── core/                    # nix.enable, home-manager, fonts — shared, you never touch
│   │   ├── nix.nix
│   │   └── fonts.nix
│   ├── darwin/                  # mac-only: homebrew (pristine), pam Touch ID, system.defaults, aerospace, sketchybar
│   │   ├── homebrew.nix
│   │   ├── desktop.nix          # aerospace + sketchybar (Hyprland lua compiles via lib/hypr-to-aerospace.nix)
│   │   └── pam.nix
│   ├── linux/                   # future linux: hyprland, quickshell, sddm — not evaluated on darwin, same omanix.theme/widgets
│   │   ├── hyprland.nix
│   │   └── quickshell.nix
│   ├── desktop/                 # picks at eval: if isDarwin then darwin/desktop.nix else linux/hyprland.nix — you just set omanix.theme
│   ├── theme/                   # themed.nix: themes/*/colors.toml + default/themed/*.tpl → /nix/store — you never touch tpl
│   ├── widgets/                 # omanix.widgets.* — pomodoro etc.
│   │   ├── pomodoro.nix         # uses lib/mkWidget: sketchybar item + launchd (mac) / systemd (linux) + optional Swift/GTK app
│   │   └── clock.nix
│   └── apps/                    # Swift apps on mac, GTK/Electron on linux — via lib/mkApp, appear as native apps
├── lib/
│   ├── mkSystem.nix             # branches: if system == "aarch64-darwin" or "x86_64-darwin" → darwinSystem, else → nixosSystem
│   ├── mkWidget.nix             # { name, sketchybarConfig|hyprlandConfig, launchdOrSystemd, swiftOrGtkSrc } → module + derivation
│   ├── mkApp.nix                # { name, bundleId/desktopFile, src } → /Applications/*.app or /usr/share/applications
│   └── themed.nix
├── themes/                      # vendored omarchy-mac/themes/*/colors.toml — build-time only
├── config/ + default/ + shell/  # vendored omarchy-mac taste — read-only, compiled by lib, never hand-edited
├── bin/
│   └── omanix                   # distro CLI: install | rebuild | generations | add <pkg> | remove <pkg> | search <pkg>
└── docs/
    ├── principles.md
    ├── philosophies.md
    └── conventions.md
```

**Why this shape — beginner simple, scalable to complexity, cross-platform:**

- **One file to learn:** `configuration.nix` is 40 lines with comments: `omanix.host = "my-mac"`; `omanix.user = "yourname"`; `omanix.theme = "tokyo-night"`; `omanix.widgets.pomodoro.enable = true`; `environment.systemPackages = with pkgs; [ ripgrep ]`. A green user who has never seen Nix reads flakes as "this file is my Mac" — no deep `modules/darwin/nix.nix` hunting day one.
- **Flakes are welcoming:** `flake.nix` is <30 lines, each line commented: `inputs.nixpkgs.url = "github:NixOS/nixpkgs/<pinned>" # the package catalog`. No `lib.mkDarwinSystem` abstraction to learn; `mkSystem` is just an `if isDarwin` branch you read once.
- **Scales without rewrites:** Need a second Mac? `hosts/work-mac/default.nix` imports `../configuration.nix` and overrides `host` + extra `homebrew.casks`. Need Linux later? Add `system = "x86_64-linux"` to `flake.nix` and `lib/mkSystem` picks `nixosSystem` + `modules/linux/hyprland.nix` — same `omanix.theme`, `omanix.widgets.pomodoro.enable` works because `modules/desktop` and `modules/widgets` branch on `isDarwin`. No mac-specific stuff leaks to Linux; no Linux `hyprland` leaks to mac.
- **Vendored taste, compiled:** `themes/`, `config/`, `default/`, `shell/` are Omanix's memory of Omarchy, compiled by `lib/themed.nix` and `lib/hypr-to-aerospace.nix`. You get the look without hand-editing `colors.toml`.
- **Tiny `packages/` by design (Principle 4) + `bin/omanix add|remove` uses `search.nixos`/`brew` so users never hand-package (Principle 11); everything in `/nix` so `uninstall` is pristine (Principle 12).
