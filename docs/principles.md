# Omanix Principles — Hard Lines

These are invariants. If a change violates a principle, the change is wrong, not the principle. Principles are ordered by precedence; higher beats lower in conflict.

---

## 1. Distro, Not Library

Omanix is the user's flake. The one-command installer clones `github:nowarelabs/omanix` to `~/.omanix` and the user edits that flake in place. `omanix rebuild` is `darwin-rebuild switch --flake ~/.omanix#<hostname>`.

We do **not** ship as `inputs.omanix.lib.mkDarwinSystem` library. The Approved decision (Distro — clone & edit) exists because Omarchy's power is a file you edit and reload. Nix purity is preserved via `flake.lock`; composability is preserved via `inputs` the _user_ adds inside their distro flake.

**Consequence:** `flake.nix` owns `darwinConfigurations.<hostname>`. User owns the file. We own the defaults inside `modules/`. Upgrades are `nix flake update` + `omanix rebuild`.

---

## 2. Native Mapping Over Emulation — No VM

macOS cannot run Hyprland / SDDM / Wayland natively. Hard line: **we do not hide a Linux VM**. (Approved: native macOS modules Omabar/Omatiles — no AeroSpace binary, no SketchyBar process.)

- **Hyprland → Omatiles:** Hyprland's tiling (workspaces, gaps, keybindings) is rebuilt as a **native SwiftUI/AppKit module inside the Omanix app** (`Modules/Omatiles/OmatilesEngine.swift`). No `aerospace` binary, no `hyprctl`; gaps/layout/watch/bindings are `omanix.omatiles.*` Nix options the app reads at runtime.
- **Quickshell → Omabar:** Quickshell's bar is rebuilt as a **native SwiftUI menu bar** (`Modules/Omabar/OmabarContentView.swift`), launched by a launchd agent with the same app binary in `--omabar` mode. Not a port of a shell config — a real AppKit `NSPanel` themed from `theme.json`.
- **SDDM → loginwindow:** Replaced by `system.defaults.loginwindow` + `security.pam` (Touch ID).

If a feature cannot be mapped natively, we cut it or re-architect for Quartz — we do not smuggle a VM or an external Linux-forged tool.

---

## 3. Build-Time Purity, No Raw Config — Never Touch .toml/.tpl/.config

Approved: Build-time (Nix-pure). Extended hard line: **the user never edits `.toml`, `.tpl`, or raw `~/.config` files to make Omanix work.**

- **Themes:** `themes/*/colors.toml` + `default/themed/*.tpl` are _internal build inputs_. The user sets `omanix.theme = "tokyo-night"` (a Nix string enum, own brand — not `omarchy.theme` spec) and Nix renders via `lib/themed.nix`. There is no `omarchy-theme-set` mutating `~/.config`.
- **Omabar/Omatiles:** The user sets `omanix.omabar.position = "top"` or `omanix.omatiles.gapInner = 8` as Nix options. They never edit a theme.omabar/omatiles config by hand; the app reads the options (and `theme.json`) at runtime.
- **Hyprland lua:** `config/hypr/*.lua` is vendored read-only. User overrides are `homeManagerConfig = { xdg.configFile... }` only via Nix, not by opening `~/.config/hypr/hyprland.lua`.

**Rationale:** Omarchy plugins are bash-imperative (`omarchy-plugin-add` git clones, writes `manifest.json`, sources scripts). Omanix rejects that model. If you need to go into a file to make it work, the abstraction is incomplete — the fix is a typed Nix option, not documentation telling you to edit a tpl.

Nix generations are the only snapshot mechanism. `omanix generations` / `omanix rebuild --rollback` reads `/nix/var/nix/profiles/system-*`.

---

## 4. Pragmatic Nix + Homebrew, No Re-packaging

Approved: Pragmatic. Hard line extension: **if it is in `search.nixos.org` (nixpkgs) or `brew search` (homebrew), we do not package it ourselves.**

- **Nix owns:** `environment.systemPackages`, `nix-darwin` modules, `home-manager` dotfiles, `launchd` services, `fonts`, CLI tools, language runtimes (not `mise`), and all Omarchy theming. If `nixpkgs` has a working `aarch64-darwin` build, you use it — e.g., `ripgrep`, `starship`, `postgresql_16`, `nodejs_22`, `rustc`.
- **Homebrew owns:** Signed GUI `.app` casks where Nix would break signing/notarization: `google-chrome`, `visual-studio-code`, `slack`, `orbstack`. Managed declaratively via `homebrew.casks`/`brews` with `onActivation.cleanup = "uninstall"` and `upgrade = true` (`config/flake.nix:110-138` pattern).
- **No custom packaging:** Do not create `packages/foo.nix` if `nixpkgs` or `homebrew` already ships it. `packages/` is only for Omanix-specific adapters (e.g., `omarchy-nvim` wrapper, the Omanix app itself with its Omabar/Omatiles modules). Before adding to `packages/`, you must show `nix search` and `brew search` miss.

This mirrors the daily driver. `omarchy-pkg-*` is deleted; the replacement is `nix flake update` or `omanix add <name>` which routes to the correct owner (see Conventions 6).

---

## 5. Declarative Device, Imperative Home Is a Bug

- No `sudo` inside `home.activation` to create `/var/lib/postgresql`. `system.activationScripts.preActivation` only for dirs that cannot be `launchd` or `users.users`.
- Dotfiles are `home.file` with `backupFileExtension`. No `ln -sf`.
- `mise`, `npm -g`, `pip --user` are not second package managers. Language versions are `nixpkgs` pins (`nodejs_22`, `ruby_3_3`, `python313`).

---

## 6. One Lock File, One Truth

`flake.lock` pins `nixpkgs`, `nix-darwin`, `home-manager`, and every plugin/app input. `917fec99094...` pins as in `config/flake.nix:5`. `nix flake update` is the only updater; `omarchy-update*` is replaced by `omanix update` → `nix flake update ~/.omanix && omanix rebuild`.

---

## 7. APFS + Nix Generations — No BTRFS Theater

APFS + FileVault only. No `snapper`, `limine`, `btrfs-migrate`, `factory-reset`. Deleted on Darwin.

---

## 8. Security Is Darwin-Native

`security.pam.services.sudo_local.touchIdAuth = true`, `system.primaryUser`, `users.users.<name>` as in `config/flake.nix:87-93`. No Linux PAM paths. Firewall is `system.defaults` + `networking.applicationFirewall`, not `ufw`.

---

## 9. No New Package Managers

No `pacman`, `yay`, `mise`, `npm -g`/`pipx` as system state. Homebrew is the _only_ second manager, and only for casks (Principle 4).

---

## 10. Apps and Widgets Are Nix Derivations, Not Bash Plugins — launchd/plist/Swift

**This replaces Omarchy's bash-plugin model. Approved: Both — SDK + auto-wrap.** Omarchy lets anyone `omarchy-plugin-add` a git repo with `manifest.json` + bash scripts, and it appears as a widget (e.g., AI-generated pomodoro widget). Omanix preserves the _capability_ — community widgets/apps that feel like native daily-drive apps — but replaces the _mechanism_ and supports both paths:

- **No bash plugins:** `omarchy-plugin-*` (git clone + `manifest.json` + sourced bash) is deleted on Darwin. Bash-imperative plugins that `echo` into `~/.config` or `pkill` at runtime cannot be reasoned about, rolled back, or signed.
- **Nix-native plugins — two paths (Both):**
  1. **Prescriptive SDK:** `lib/mkWidget` / `lib/mkApp` helpers take `{ name, src (Swift), plistConfig, launchdConfig }` and return a module. Authors publish a flake with `omanixWidgets.pomodoro` or `packages.pomodoro`.
  2. **Auto-wrap:** `omanix add github:you/pomodoro-swift` with a single `Sources/*.swift` file is auto-wrapped — Omanix detects Swift, builds via `swift build`/`xcodebuild`, and generates the `launchd` plist without requiring a full SDK flake.
- **UX:** Either way, it may produce any of: a `launchd` agent (`launchd.user.agents.pomodoro`), a **Swift/SwiftUI app** (`packages/pomodoro-app` → `/Applications` via `home.file`), or — for bar items — an item registered with the native **Omabar** module. All hashed and added via options.
- **Example — pomodoro:** On Omarchy, `omarchy-plugin-add pomodoro` drops a bash widget. On Omanix, `omanix add pomodoro` adds `inputs.omanix-pomodoro.url = "github:you/pomodoro-omanix"` and `omanix.widgets.pomodoro.enable = true;` — which enables a `launchd` timer (`/Applications/Pomodoro.app` when `swiftSrc` is given) built by Nix. It appears as if you installed a Mac app, but it is a Nix derivation that disappears on `omanix remove pomodoro && omanix rebuild`.

This gives macOS what you wanted: "on Mac I would have had to install a Mac app for this" — now you do, but the Mac app _is_ the Nix plugin, built reproducibly.

---

## 11. Fast, Reliable Add/Remove — nixpkgs/homebrew Are the Registry — Auto `omanix add`

**Approved: Auto `omanix add` is the primary UX. Do not make the user package or search manually.** Help them get applications/packages quickly and remove them quickly and reliably — using the platforms' registries, not our own.

- **Routing (Auto):** `omanix add <name>` (and `omanix remove <name>`) is the canonical path. It checks `search.nixos.org` (`nix search`) first; if found, it edits `flake.nix` to add `pkgs.<name>` to `environment.systemPackages`/`home.packages` and rebuilds. If not in `nixpkgs` but in `brew search` (cask/brew), it adds to `homebrew.casks`/`brews`. If neither, it suggests `omanix add github:...` for Swift/widget auto-wrap or manual input. Manual `flake.nix` editing still works but `omanix add` is how users are taught.
- **No duplicate registry:** We do not keep an `omanix/packages.json` catalog that re-lists nixpkgs/brew. The system _is_ the catalog.
- **Reliability:** Adds and removes are declarative edits + `nix flake lock --update-input` + rebuild; we verify with `nix flake check` and `darwin-rebuild check` before switching, so failures do not leave half-state.

---

## 12. Pristine Mac Guarantee — Full Pristine — Uninstall Leaves No Trace

**Approved: Full pristine. If the user stops using Omanix, their Mac is pristine — including casks Omanix added.** All system state lives in `/nix/store`, `/nix/var/nix/profiles`, the flake repo at `~/.omanix`, and (for casks) `/Applications` symlinks managed by Homebrew. Uninstall is:

```bash
/nix/nix-installer uninstall
rm -rf ~/.omanix
sudo rm /Library/LaunchDaemons/org.nixos.* 2>/dev/null; true
# All homebrew casks/brews added via homebrew.casks/brews are removed because onActivation.cleanup = "uninstall"
```

Because:

- No file is ever `curl | sh` outside Nix (only Determinate installer, itself reversible).
- No `~/Library/LaunchAgents` plist is written outside `launchd.user.agents` (which `nix-darwin` removes on uninstall).
- Homebrew is on `cleanup = "uninstall"`, so `casks` installed by Omanix vanish when the flake is gone and the user runs `brew uninstall` (or we run it during `omanix uninstall`).
- No `~/.config/hypr/*`, `~/.config/sketchybar/*`, `~/.config/aerospace/*` exists (or survives) as a hand-edited file — those stacks were removed; the bar/tiling live inside the Omanix app. What remains is store-symlinked and backed up via `home-manager.backupFileExtension = "backup"`, so uninstall leaves no Omanix residue.
- Swift apps installed as derivations live in `/nix/store` and are symlinked to `/Applications` via activation; uninstall unlinks them.

We track every path we manage so we can delete it. This is tested: `tests/pristine` does `darwin-rebuild switch` → `omanix add google-chrome` → `switch` → `omanix uninstall` and asserts no `/nix`, no `launchd` leftover, no `/Applications/Omanix*`, no Omanix-added casks remain.

---

## 13. Failure Mode Is Rollback, Removal Is Uninstall

Every `add`/`remove`/`update` must be undoable in <30s via `omanix rebuild --rollback` (generations) and fully removable via `omanix uninstall`. If a module would need destructive `/var/lib` migration, it is a manual migration in `docs/migrations.md` with a guard, not an implicit activation.

---

## 14. GUI for Humans Who Don't Live in Terminal — Omanix Store Is a Widget, Enabled by Default

Omanix commands are `omanix rebuild`, `omanix add`, `omanix generations` — a green Mac user who has never used Nix should not need them. Hard line: **we ship a GUI that looks like the Mac App Store, for installing packages, toggling widgets, and OS settings, the GUI is itself a plugin, and it is enabled by default.**

- **What it is:** `modules/apps/store/` → `lib/mkApp` SwiftUI app on macOS (GTK on future Linux) that appears as `/Applications/Omanix Store.app`, as `Super → Omanix Store` in the Omarchy menu, and as `omanix store` CLI. It is `omanix.widgets.store.enable = true` by default in `configuration.nix` — a derivation, not a hand-installed `.app`. Power users disable with `omanix.widgets.store.enable = false;` + rebuild.
- **What it does for green users:** Browse the catalog that `search.nixos.org` + `brew search` already is (cached), one-click `Install` → calls `bin/omanix add` helper (edits `configuration.nix`, runs `nix flake check` dry, `omanix rebuild`), toggle `omanix.widgets.pomodoro` switches, pick `omanix.theme` with live preview, tweak `system.defaults` (dock, trackpad) with sliders — no terminal, no `.nix` syntax to learn day one.
- **Why it must be a plugin (and by default):** If the Store were imperative or opt-in, a green user would never find it. Because it is a Nix derivation via `lib/mkApp` and on by default, first boot already has `Super → Store`, and `omanix uninstall` removes it like any widget, `omanix rebuild --rollback` undoes a Store `Install` in 30s. The Store eats its own dogfood — it edits `configuration.nix` via structured helpers (`libexec/omanix-add.sh`), not `echo`.

---

## 15. AI-Agent-Ready by Contract — Same End Goal, Mac-Native Realization

Your friend's map is right on the end goal — _user says "make pomodoro", Claude writes it, it just appears themed and isolated_ — but wrong on the macOS substrate if taken literally. Friend assumes NixOS + `~/.config` impure Home Manager imports + Quickshell QML hot-reload via D-Bus. Omanix is Darwin-native: **native Omabar/Omatiles SwiftUI modules in the Omanix app** + `launchd` + `Swift` on macOS, `Hyprland`/`Quickshell`/`systemd` on future Linux. Hard line: **Omanix is AI-ready by providing a typed Nix contract, a machine-readable skill, and a two-phase build (preview → commit) that is mac-native and cross-platform, not by letting an agent `echo` into `/nix/store` or `~/.config` imperatively.**

Friend's core insight we keep:

> Nix is immutable; `~/.config` imperative drift breaks reproducibility; bridge with flakes + dynamic imports + declarative UI (QML). Provide `lib.mkPlugin` with `theme` injection, dependencies as `pkgs`, and a `SKILL.md` with linter.

Friend's substrate we adapt:

| Friend (Linux)                                                                                                              | Omanix (macOS now, Linux future — same `omanix.widgets`)                                                                                                                                                                                                                                                                                                                                                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `~/.omanix/plugins/pomodoro/{default.nix, widget.qml}` (Home Manager `--impure` scan)                                | `~/.omanix/overlays/pomodoro/{default.nix, Sources/*.swift}` **preview** overlay (impure, git-ignored) **plus** committed `configuration.nix` `omanix.widgets.*` / `inputs.*` (pure). No `--impure` in final build.                                                                                                                                                                                                                                                   |
| `lib.mkPlugin { name, type = "bar-widget", source = ./widget.qml, style = "${theme.colors.base01}", dependencies = [mpv] }` | `lib/mkWidget { name = "pomodoro", launchdConfig, swiftOrGtkSrc, style = "${config.lib.omanixTheme.colors.accent}", dependencies = [pkgs.libnotify pkgs.mpv] }`—`theme` comes from `lib/themed.nix`, not `stylix`, and `pkgs` paths are Nix-resolved. Bar items register with the native Omabar module instead of a sketchybar plugin. |
| `SKILL.md` at `~/.claude/skills/omanix.md` + `statix`/`nixpkgs-fmt` in PATH                                                 | Same, but Omanix ships it: `skills/omanix/SKILL.md` (machine-readable schema + `mkWidget`/`mkApp` examples for both mac and Linux) installed to `~/.omanix/skills/` and symlinked to `~/.claude/skills/omanix/` / `~/.opencode/skills/omanix/` by `home.file`. Agents run `nix fmt` + `statix check` + `nix-instantiate --parse` before `omanix rebuild`.                                                                                                             |
| Quickshell `Qt.createComponent()` + D-Bus IPC to reload                                                                     | **Mac:** `launchctl kickstart -k gui/$UID/om.omanix.omabar` + `launchctl load ~/Library/LaunchAgents/org.omanix.*.plist` (generated) + `/Applications/*.app` symlink swap. **Future Linux:** `quickshell ipc call` + `systemctl --user daemon-reload`. Same `omanix rebuild` triggers the right IPC branch via `pkgs.stdenv.isDarwin`.                                                                                                                                                                    |
| `omanix-rebuild` = `home-manager switch --flake` (`--impure` for drop-ins)                                                  | **Omanix two-phase:** `omanix rebuild --preview` — evaluates `overlays/*/default.nix` impurely (no `flake.lock` update, no generation, hot-reload via IPC, instant feedback, not tracked) ; `omanix add` — promotes the overlay to `configuration.nix` `inputs.*` + `omanix.widgets.*.enable`, runs `nix flake lock --update-input`, `nix flake check`, `omanix rebuild` (pure, generation, rollbackable). AI is instructed to always `preview` then ask "keep?" then `add`. |

**Our end-to-end (same user delight, Nix-native, mac-ready — now with permanent impure allowed):**

1. **User:** _"Hey Claude, make me a pomodoro timer plugin."_
2. **Agent (draft & lint, no build):** Reads `skills/omanix/SKILL.md` (typed `mkWidget` contract, theme tokens `config.omanix.theme.colors.*`, examples), writes `overlays/pomodoro/{default.nix, Sources/ContentView.swift}` (`overlays/` git-ignored by default), runs `nix fmt`, `statix check`, `nix-instantiate --parse` — all linters are auto-installed by `bin/omanix install` (`statix` + `nixfmt` + `nixd` in agent PATH, approved).
3. **Agent (preview, impure, instant, no generation):** `omanix rebuild --preview` — Nix evaluates `overlays/*` impurely (`builtins.readDir ../overlays`), builds `/nix/store/...-pomodoro` with `${theme.colors.accent}` injected, hot-reloads via `launchctl kickstart -k gui/$UID/om.omanix.omabar` (mac) / `quickshell ipc` + `systemctl` (linux). Widget appears instantly.
4. **Agent (commit OR keep impure — user chooses, approved: allow permanent impure):**
   - **Pure commit (tracked, rollbackable, Store-visible):** `omanix add pomodoro --from-overlay overlays/pomodoro` — moves overlay to `inputs.pomodoro` + `omanix.widgets.pomodoro.enable` in `configuration.nix`, `nix flake lock --update-input`, `nix flake check`, `omanix rebuild` (pure, new generation). `overlays/` cleared. This is the default the skill teaches (green user sees toggle in Store).
   - **Permanent impure (fast, no lock, instant, no generation beyond overlay delete):** Keep `overlays/pomodoro/` and run `omanix rebuild` (without `--preview`) — `configuration.nix` still imports `overlays/*` impurely every rebuild, no `flake.lock` entry, no generation beyond overlay file existence. The agent keeps `overlays/` and documents it as `overlays/pomodoro/README.md: impure — delete folder to remove`. This is allowed per approval for rapid AI iteration where lock churn is unwanted; `omanix uninstall` still deletes `overlays/` so pristine holds, but `rollback` is `rm -rf overlays/pomodoro && omanix rebuild --preview` not a generation.
5. **Undo:** Pure path: `omanix rebuild --rollback` or `omanix remove pomodoro`; impure path: `rm -rf overlays/pomodoro && omanix rebuild --preview`.

Why this beats friend's _only_ `--impure` forever: we keep preview speed but make persistence a choice — pure for teams/Store visibility/rollback, impure for throwaway AI experiments. Linters are ready day one (`bin/omanix install` puts `statix`/`nixfmt`/`nixd` in PATH), so the agent never writes invalid Nix. On Linux, same `overlays/` becomes `widget.qml` + `systemd` — `lib/mkWidget` branches on `isDarwin`.

---

## Architecture That These Principles Demand — Simple for Green Users, Ready for Linux

**Beginner edits one file. Complexity scales, not starts complex.**

```
omanix/                          # distro flake — cloned to ~/.omanix (or ~/.local/share/omanix)
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
│   ├── darwin/                  # mac-only: homebrew (pristine), pam Touch ID, system.defaults, omabar, omatiles
│   │   ├── homebrew.nix
│   │   ├── omabar.nix           # native SwiftUI menu bar (launchd agent → Omanix.app --omabar)
│   │   ├── omatiles.nix         # native window tiling (launchd agent → Omanix.app --omatiles)
│   │   └── pam.nix
│   ├── linux/                   # future linux: hyprland, quickshell, sddm — not evaluated on darwin, same omanix.theme/widgets
│   │   ├── hyprland.nix
│   │   └── quickshell.nix
│   ├── desktop/                 # picks at eval: if isDarwin then darwin/omabar.nix + omatiles.nix else linux/hyprland.nix — you just set omanix.theme
│   ├── theme/                   # themed.nix: themes/*/colors.toml + default/themed/*.tpl → /nix/store — you never touch tpl
│   ├── widgets/                 # omanix.widgets.* — pomodoro etc.
│   │   ├── pomodoro.nix         # uses lib/mkWidget: launchd (mac) / systemd (linux) + optional Swift/GTK app; bar items register with Omabar
│   │   └── clock.nix
│   └── apps/                    # Swift apps on mac, GTK/Electron on linux — via lib/mkApp, appear as native apps
├── lib/
│   ├── mkSystem.nix             # branches: if system == "aarch64-darwin" or "x86_64-darwin" → darwinSystem, else → nixosSystem
│   ├── mkWidget.nix             # { name, launchdConfig|systemdConfig, swiftOrGtkSrc } → module + derivation
│   ├── mkApp.nix                # { name, bundleId/desktopFile, src } → /Applications/*.app or /usr/share/applications
│   └── themed.nix
├── themes/                      # Omanix themes (colors.toml) — build-time only
├── config/ + default/ + shell/  # Omanix theme sources — read-only, compiled by lib, never hand-edited
├── bin/
│   └── omanix                   # install | rebuild | rebuild --preview | generations | add | remove | search | store | ask --local
├── skills/
│   ├── omanix/
│   │   ├── SKILL.md             # full skill for frontier Claude/OpenCode
│   │   └── mini-SKILL.md        # tiny skill for local Qwen 3-7B (JSON schema, 2 few-shots)
│   └── local-ollama/            # qwen2.5:7b pulled by `omanix setup local-ai` (Ollama, config/ollama.plist)
├── overlays/                    # git-ignored AI preview drop-ins: overlays/pomodoro/{default.nix} → preview impure or permanent impure
└── docs/
    ├── principles.md
    ├── philosophies.md
    └── conventions.md
```

## 16. Local AI (Qwen) for Light Tasks, Frontier for Heavy — Same Contract, Tiny Skill

Not every task needs frontier Claude. A green user saying _"make it darker"_ or _"add ripgrep"_ should not pay a cloud round-trip or leak privacy. Hard line: **Omanix is ready for both local Qwen (Ollama, offline, not-heavy) and frontier (Claude/OpenCode, cloud, heavy) — same `omanix.widgets` contract, different tier, small skill for small model.**

- **Local tier (Qwen 3-7B via Ollama, offline, private, fast — opt-in only):** Handles not-heavy, local tasks — `omanix.theme = "matte-black"`, `omanix.widgets.clock.enable = true`, `omanix add ripgrep` (routes `nix search`/`brew search`), or a simple timer widget by filling a `lib/mkWidget` template (approved: allow template fill, not just toggles). Uses **mini skill** `skills/omanix/mini-SKILL.md` (JSON schema + 2 few-shot `mkWidget` template fills, no full Swift generation) and **constrained tools** (`omanix add`, `omanix remove`, `omanix widgets toggle`, `mkWidget` template). Runs via `ollama` (`config/ollama.plist` + `config/nix/ollama.plist`) with `qwen2.5:7b`/`qwen3:8b` pulled only when user runs `omanix setup local-ai` (opt-in, ~4GB, no prompt at install). Invoked as `omanix ask --local "make pomodoro"` or Store's `Ask (offline)` bar or `Super → Ask`.
- **Frontier tier (Claude Code/OpenCode, heavy):** Full `skills/omanix/SKILL.md`, `lib/mkWidget`/`lib/mkApp` with Swift/QML sources, theme injection, multi-file widgets. Same `overlays/` preview → commit flow.
- **Same contract, tiny vs full:** Both tiers write the same `omanix.widgets.*` options and `overlays/*/default.nix` shape; local just stays within `nix fmt` + `statix` + `omanix add` safe actions. If Qwen emits invalid Nix, `statix` fails and the skill falls back to `omanix ask --local --dry-run` showing the diff, never `echo` into `~/.config`.

A green user with no API key still gets AI help offline; a power user with Claude still gets the full Swift app.
