# Omanix Philosophies — Why We Build This Way

Philosophies are opinions with a point of view. Principles are the hard walls; philosophies explain why the walls are where they are.

---

## 1. Omarchy Taste, Nix Engineering — Without the Bash Glue

Omarchy is taste — `tokyo-night` at 3am, `foot` + `nvim` + `tmux`, a bar that flows around the notch, `Super` then type. Nix is engineering — reproducibility, atomicity, rollback.

Omarchy delivers taste via bash: `omarchy-plugin-add` clones a repo with `manifest.json`, sources `*.sh`, writes `~/.config`. That glue is imperative — it cannot be hashed, rolled back, or reasoned about. Omanix loves Omarchy's taste but rejects its glue:

- Every Omarchy default that defines *feel* — `default/hypr/*.lua`, `config/omarchy/shell.json`, `themes/*/colors.toml`, `default/themed/*.tpl`, `shell/` QML — is vendored read-only and compiled by Nix. Taste is not reimplemented.
- Every mechanism that defines *state* — `pacman -S`, `yay`, `omarchy-pkg-add`, `mise`, `omarchy-theme-set` at runtime, `home.activation` git clones — is replaced by Nix derivations and launchd.

Philosophy: **If it was bash that wrote a file to `~/.config` at runtime, it should have been Nix that rendered that file at build time.**

---

## 2. The Mac Is Not a ThinkPad With a Different Logo

Omarchy-mac treats the Mac as generic Linux hardware: Asahi Alarm repartitions, BTRFS, `m1n1 → u-boot → GRUB`. Omanix treats the Mac as a Mac:

- **Quartz is the compositor.** AeroSpace tiles within Quartz; SketchyBar draws on Quartz. The notch is not an obstacle — the bar is split around it (`hero.jpg` is a promise).
- **APFS + FileVault is the filesystem.** No BTRFS migration.
- **The keyboard is the keyboard.** Media keys, `fnmode`, trackpad haptics are Apple-native.

Philosophy: **If Linux has a macOS counterpart the user expects, use the counterpart and compile the Linux config to it.**

---

## 3. One Machine, One File, One Lock — And No One Edits a .toml to Make It Work

`config/flake.nix` pins `nixpkgs 917fec99094...`, `nix-darwin 52d0615...`, `home-manager 27b93804...` and defines `darwinConfigurations."Vances-MacBook-Pro"` in 259 lines. That file *is* the machine.

Omanix extends that to mean: **you do not go into `.toml`, `.tpl`, or `~/.config` to make stuff work.** If you need to, the option is missing — we add a Nix option, not a wiki page.

- Want `tokyo-night`? Set `omanix.theme = "tokyo-night"` — don't edit `themes/tokyo-night/colors.toml`.
- Want bar on bottom, transparent? `omanix.bar.position = "bottom"; omanix.bar.transparent = true;` — don't open `sketchybarrc` or `default/themed/*.tpl`.
- Want a new keybinding? `desktop.aerospace.bindings."cmd-1" = "workspace 1"` — don't edit `default/hypr/bindings.lua`.

`themes/`, `default/themed/*.tpl`, `config/` are internal build inputs. The flake is the config; `~/.config` is a build artifact in `/nix/store`. You do not go into those files; Nix goes into them for you.

---

## 4. Pragmatism Has a Boundary, and the Boundary Is the Registry

Why **Pragmatic Nix+Homebrew** and **No Re-packaging**?

Because the registry already exists: `search.nixos.org` for Nix, `brew search` for Homebrew. If a package is there, packaging it again in `packages/` is busywork that drifts and breaks signing.

- Nix owns CLI, LSP, compilers, DBs, fonts — anything with an `aarch64-darwin` build (`ripgrep`, `starship`, `postgresql_16`). You `omanix add ripgrep` and it becomes `pkgs.ripgrep`.
- Homebrew owns signed GUI `.app` casks (`google-chrome`, `vscode`, `slack`, `orbstack`) — because Nix would have to symlink and break notarization.

Philosophy: **Pragmatism is not laziness; it is respect for the registry and for platform signing.** Nix for what Nix can be truthful about; Homebrew for where Nix would have to lie; never our own re-package when either already ships.

This also means `brew` is never imperative. It is a Nix-controlled activation with `cleanup = "uninstall"` — the casks you added vanish when you remove them from the flake and rebuild.

---

## 5. Build-Time Is Honesty, Runtime Is a Pomodoro That Isn't There After Reboot

Why **Build-time (Nix-pure)** for themes and widgets?

On Arch, `omarchy-theme-set` writes `~/.config` and you see it now. On Nix, the next `darwin-rebuild` would revert it and you'd file a bug. Build-time is honest:

```nix
# ~/.config/omanix/flake.nix — the only place you edit
omanix.theme = "tokyo-night";           # rebuild to change, rolls back with generations
omanix.widgets.pomodoro.enable = true; # not `omarchy-plugin-add pomodoro` at runtime
```

The pomodoro example matters: on Omarchy, someone used AI to create a pomodoro plugin and it appeared as a widget. On Mac, you'd have installed a Mac app. Omanix makes those the same thing: a **Nix-native widget/app** — a derivation that may be a SketchyBar item (`modules/widgets/pomodoro.nix`), a `launchd` agent (`launchd.user.agents.pomodoro`), or a Swift app bundle (`packages/pomodoro-app` → `/Applications/Pomodoro.app`). It is enabled by flipping a Nix bool, not by `git clone` at login. It appears instantly after rebuild and disappears completely after `omanix.widgets.pomodoro.enable = false` + rebuild.

If you want live feedback while hacking a widget, `nix develop` gives you SketchyBar live-reload against the store path — not a mutated home directory.

Philosophy: **A widget is an app with a Nix hash. If it cannot be `nix why-depends`'d, it is not a widget.**

---

## 6. Familiarity Is a Feature, But Shims Are Not Bash

Omarchy's CLI is delightful: `omarchy menu`, `omarchy launch`, `omarchy capture`. Omanix keeps the vocabulary — but as typed shims, not bash plugins:

- If the concept maps (e.g., `omarchy-hyprland-focus-app` → `aerospace focus`), the shim translates.
- If it does not (e.g., `omarchy-system-btrfs-migrate`, `omarchy-refresh-pacman-mirrorlist`), the shim is deleted and prints `not available on Darwin — see docs/porting.md`.
- No shim sources bash from a plugin repo. Widgets/apps are not bash; they are Nix modules + Swift/launchd (Principle 10).

Philosophy: **Keep the words, replace the mechanism with something Nix can see.**

---

## 7. Small Core, Typed Edges, Instant Gratification

Omarchy-mac is large: 444 bin commands, 23 themes, 36 `default/*` trees. Omanix ships a small core that boots, then typed edges:

- **Core (v1):** AeroSpace + SketchyBar + `tokyo-night`/`catppuccin`/`matte-black`, `foot`/`ghostty`, `starship`, `tmux`, `nvim`, and the daily-driver services (postgres/redis). Enough to pass `darwin-rebuild switch`.
- **Edges (typed):** `capture` → `screencapture` shim, `install dev env` → `extraPackages`, `hw` → Mac detection. Each edge is a Nix option + test.

But edges must also be **fast to get and fast to lose** — because `search.nixos` and Homebrew are the registry, not us:

```bash
omanix add neovim          # → nixpkgs, rebuild in seconds
omanix add google-chrome   # → brew cask, rebuild
omanix remove neovim       # → edit flake, rebuild, generation rolls back, no leftover
```

Philosophy: **Help the user get applications quickly and reliably, and remove them just as quickly, with nothing left behind.** That is only possible when every add is a derivation + lock-file entry, not a bash script that curled.

---

## 8. The Bar Is the Contract, the App Is the Widget

If `hero.jpg` shows workspaces flowing around the notch, the bar better flow around it. Theme tokens (`accent #7aa2f7`, `background #1a1b26` in `tokyo-night/colors.toml`) are the design system; the bar is the proof.

Widgets extend that contract: a pomodoro widget is not a floating bash window — it is a SketchyBar item with `colors.toml` tokens, a `launchd` timer that fires `osascript` or Swift code, and optionally a Swift menubar app that shares the same Nix-built assets. It looks like a Mac app because it *is* a Mac app — but one whose source is in the flake and whose binary is in `/nix/store`.

Philosophy: **If it looks like a Mac app, it should be built like a Nix derivation and behave like a SketchyBar token.**

---

## 9. Your Flake Is Your Dotfiles, Versioned — Until You Leave

`config/home.nix` is 138 lines of `programs.zsh.initContent` and aliases like `osrebuild`. Omanix makes that history first-class: `~/.config/omanix` is a git repo, `system.configurationRevision = self.rev` stamps every generation.

And leaving is pristine: uninstall removes `/nix`, the `LaunchAgents` that were Nix-managed, the `/Applications` symlinks for Nix-built apps, and the Homebrew casks (with `cleanup = "uninstall"`). No `~/Library/LaunchAgents/org.foo.plist` hand-written by a bash plugin survives, because no plugin was ever allowed to write there — only `launchd.user.agents` did.

Philosophy: **You should be able to try Omanix for a week and leave your Mac cleaner than you found it.**

---

## 10. Less Magic, More Derivation — No One Opens a .config to Understand

Where Omarchy-mac uses magic — `omarchy-refresh-config hypr/hyprland.lua` copying with `[[ -e ]]` (AGENTS.md:111-121), `$OMARCHY_PATH` env, `uwsm` session — Omanix uses derivations.

Why: magic hides provenance. macOS already has too much magic (SIP, TCC, quarantine). A derivation has a hash; a copied file has a timestamp. And a derivation does not require you to open `.config` to understand what happened — you read `flake.nix`.

Philosophy: **If you cannot `nix why-depends` it and you had to open a `.toml` to fix it, it is not done.**
