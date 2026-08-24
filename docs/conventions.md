# Omanix Conventions — How We Build

Conventions are the agreements that let principles and philosophies turn into code without bikeshedding. Follow them, or propose a patch to change them.

---

## 1. Folder Structure — Simple for Green Users, Scales to Complexity, Ready for Linux

This is the **approved** tree. Beginner sees `configuration.nix`; complexity scales via `hosts/` and `modules/`; Linux is a future `system = "x86_64-linux"` branch already stubbed.

```
omanix/                              # flake root — cloned to ~/.config/omanix (beginner: you edit configuration.nix)
├── flake.nix                        # ~30 lines, commented: pinned inputs + mkSystem helper → darwinConfigurations + future nixosConfigurations
├── flake.lock
├── configuration.nix                # ⭐ THE file you edit: omanix.host, omanix.user, omanix.theme, omanix.widgets.*, packages, casks — typed, no raw .toml
├── home.nix                         # your dotfiles (zsh, git, starship) — optional, most users keep everything in configuration.nix
├── hosts/                           # scalable: one folder per machine, all import ../configuration.nix + ../hosts/common.nix
│   ├── my-mac/
│   │   └── default.nix              # thin overlay: { networking.hostName = "my-mac"; } — add host-only pkgs here
│   ├── work-mac/
│   │   └── default.nix              # second mac — same theme/widgets, different host
│   └── common.nix                   # shared between darwin + future linux (theme, widgets, add/remove helpers)
├── modules/
│   ├── core/                        # shared: nix.enable, home-manager, fonts — you never touch
│   ├── darwin/                      # mac-only: homebrew (pristine), pam Touch ID, system.defaults, desktop
│   │   ├── homebrew.nix
│   │   ├── desktop.nix              # picks aerospace + sketchybar (Hyprland lua compiles via lib/hypr-to-aerospace.nix)
│   │   └── pam.nix
│   ├── linux/                       # future linux: hyprland, quickshell, sddm — not evaluated on darwin, same omanix.theme/widgets
│   │   ├── hyprland.nix
│   │   └── quickshell.nix
│   ├── desktop/                     # branch: if isDarwin then darwin/desktop.nix else linux/hyprland.nix — you just set omanix.theme
│   ├── theme/                       # themed.nix: themes/*/colors.toml + default/themed/*.tpl → /nix/store
│   ├── widgets/                     # omanix.widgets.* — pomodoro etc. (launchd on mac, systemd on linux via same option)
│   │   ├── pomodoro.nix             # uses lib/mkWidget: sketchybar/hyprland item + launchd/systemd timer
│   │   └── clock.nix
│   └── apps/                        # Swift apps on mac, GTK/Electron on linux — via lib/mkApp, appear as native apps
├── lib/
│   ├── mkSystem.nix                 # if system == "aarch64-darwin" or "x86_64-darwin" → darwinSystem else → nixosSystem
│   ├── mkWidget.nix                 # { name, sketchybarConfig|hyprlandConfig, launchdOrSystemd, swiftOrGtkSrc } → module + derivation
│   ├── mkApp.nix                    # { name, bundleId/desktopFile, src } → /Applications/*.app or /usr/share/applications
│   └── themed.nix                   # colors.toml + *.tpl → store (user never touches tpl)
├── themes/                          # vendored omarchy-mac/themes/*/colors.toml — build-time only
├── config/ + default/ + shell/      # vendored omarchy-mac taste — read-only, compiled by lib
├── bin/
│   └── omanix                       # install | rebuild | generations | add <pkg> | remove <pkg> | search <pkg> → search.nixos/brew routing
└── docs/
    ├── principles.md
    ├── philosophies.md
    └── conventions.md
```

**How a green user reads this:**

1. `flake.nix` comments: "edit `configuration.nix` to change your Mac". No deep `modules/darwin/nix.nix` hunting day one.
2. `configuration.nix` header: `# Welcome to Omanix — change host, user, theme, widgets here, then `omanix rebuild`` — each option has a comment with an example and a `# see docs/` link.
3. `hosts/` is optional: one-machine users never create it. Two-machine users `cp -r hosts/my-mac hosts/work-mac` and change `host`.
4. Linux future: same `omanix.theme`, `omanix.widgets.pomodoro.enable` works on both because `modules/desktop` and `modules/widgets` branch on `pkgs.stdenv.isDarwin`. No mac-specific file leaks to Linux eval.

**Vendored read-only:** `themes/`, `config/`, `default/`, `shell/` from `../omarchy-mac` at pinned rev. Changes from upstream sync PRs only.

**Daily-driver diff target:** Your daily `config/flake.nix` + `config/home.nix` should diff cleanly to `configuration.nix` + `home.nix` one-to-one.

---

## 2. Flake Contract — Distro Clone, No Raw Config

`flake.nix` is the machine. The user never opens a `.toml`/`.tpl`/`.config` to make Omanix work — they set Nix options:

```nix
{
  # ~/.config/omanix/flake.nix — the only file you edit
  omanix.theme = "tokyo-night";                 # not themes/tokyo-night/colors.toml
  desktop.aerospace.gaps.inner = 8;              # not aerospace.toml
  desktop.sketchybar.position = "top";           # not sketchybarrc
  omanix.widgets.pomodoro.enable = true;        # not git clone manifest.json
  omanix.widgets.pomodoro.enable = true;        # Swift app → /Applications/Pomodoro.app via lib/mkApp (launchd on mac, systemd on linux)
}
```

No `xdg.configFile."aerospace/aerospace.toml".text` raw escape hatch in normal use. If you need it, the option is missing — add the option, don't document a raw edit. This is linted: `tests/cli` fails if a home config contains `xdg.configFile.*.text` that duplicates an existing `omarchy`/`desktop` option.

Installer (`nix run github:nowarelabs/omanix#install`):

1. `curl determinate Nix` if `which nix` fails
2. `git clone` → `~/.config/omanix`
3. Prompt `hostname`/`username` and `sed` into `darwinConfigurations."<hostname>"` + `system.primaryUser`/`users.users`
4. `darwin-rebuild switch --flake .#<hostname>`

`omanix` binary:

```bash
#!/bin/bash
case "$1" in
  rebuild) shift; [[ "$1" == --rollback ]] && exec sudo darwin-rebuild --rollback || exec sudo darwin-rebuild switch --flake ~/.config/omanix#$(scutil --get LocalHostName) "$@" ;;
  generations) darwin-rebuild --list-generations ;;
  update) nix flake update ~/.config/omanix && omanix rebuild ;;
  add) shift; ./lib/omanix-add.sh "$@" ;;      # routes via search.nixos/brew (see 6)
  remove) shift; ./lib/omanix-remove.sh "$@" ;;
  search) shift; nix search nixpkgs "$1"; brew search "$1" ;;
  *) echo "usage: omanix {rebuild|generations|update|add|remove|search}" >&2; exit 1 ;;
esac
```

---

## 3. Native Mapping — Hyprland → AeroSpace (Single File)

`lib/hypr-to-aerospace.nix` is the only mapping. No scattered translations.

| Omarchy (Hyprland) | Omanix (AeroSpace) |
|---|---|
| `bind = SUPER, 1, workspace, 1` | `mods = "cmd", key = "1"` |
| `windowrulev2` | `workspace-to-monitor-force-assignment` |
| `gaps/borders` (`looknfeel.lua` + `colors.toml` accent `#7aa2f7`) | `gaps.inner`, `gaps.outer`, `border_active` |

If no AeroSpace equivalent, delete shim and document in `docs/porting.md`.

---

## 4. SketchyBar — Quickshell Tokens, No Raw .tpl

`lib/themed.nix` reads `themes/<name>/colors.toml` (`accent`, `background`, `foreground`…) and renders `default/themed/*.tpl` (`{{ accent }}`) at build time. Output is `/nix/store/.../share/omanix/themed/*` symlinked via `xdg.configFile` — but the user toggles it via:

```nix
omanix.theme = "tokyo-night";
omanix.bar = { position = "top"; transparent = false; layout.left = ["omarchy.menu" "omarchy.workspaces"]; };
```

Not via `default/themed/*.tpl`. `shell/` QML is never executed; its tokens are the reference for SketchyBar plugin reimplementation in `modules/desktop/sketchybar/plugins/*.nix`.

---

## 5. Widgets and Apps Are Nix Derivations — Not Bash Plugins

This is the **pomodoro contract**. Omarchy lets someone AI-generate a pomodoro bash plugin and it appears as a widget. Omanix lets someone AI-generate a pomodoro *Nix widget* and it appears as if you installed a Mac app — because you did (a Nix-built one).

**Approved: Both — prescriptive SDK + auto-wrap.** Authors can publish a proper flake with `omanixWidgets.<name>` using the SDK, *or* a user can `omanix add github:you/pomodoro-swift` with a single `Sources/*.swift` file and Omanix auto-wraps it (detects Swift, builds via `swift build`/`xcodebuild`, generates `launchd` plist + SketchyBar item).

**Helpers — `lib/mkWidget.nix` and `lib/mkApp.nix`:**

```nix
# modules/widgets/pomodoro.nix
{ lib, pkgs, config, ... }:
let widget = inputs.lib.mkOmanixWidget {
  name = "pomodoro";
  sketchybarConfig = { icon = "󰔟"; label = "25:00"; colorsFromTheme = true; };
  launchdConfig = { StartInterval = 60; ProgramArguments = [ "${pkgs.pomodoro}/bin/pomodoro-tick" ]; };
  # or swiftSrc = ./pomodoro-app/Sources — built via xcodebuild, yields /Applications/Pomodoro.app
};
in { options.omanix.widgets.pomodoro.enable = lib.mkEnableOption "pomodoro widget"; config = lib.mkIf config.omanix.widgets.pomodoro.enable widget; }
```

```nix
# modules/apps/pomodoro.nix (Swift menubar app)
{ lib, pkgs, ... }:
let app = lib.mkOmanixApp {
  name = "Pomodoro";
  bundleId = "org.omanix.pomodoro";
  swiftSrc = ../packages/pomodoro-app; # Sources/*.swift, built via swift build / xcodebuild
  plistConfig = { LSUIElement = true; }; # menubar-only
};
in { ... }
```

Rules:
- No `manifest.json`. No `omarchy-plugin-add` git clone. No `home.activation` bash that `mkdir -p ~/.config/omarchy/plugins && git clone`.
- Publishing: author publishes a flake with `omanixWidgets.pomodoro` or `packages.pomodoro`. User adds `inputs.pomodoro.url = "github:you/pomodoro-omanix"` and enables `omanix.widgets.pomodoro.enable = true` + rebuild. `omanix add pomodoro` can automate the `inputs` edit (see 6).
- Build uses `nixpkgs` Swift toolchain or `xcodebuild` wrapper; result is a derivation in `/nix/store/...-Pomodoro.app`, symlinked to `/Applications/Pomodoro.app` via activation. Uninstall unlinks it (Pristine, Principles 12).
- SketchyBar items and `launchd` plists are similarly generated — never hand-written to `~/Library/LaunchAgents`.

---

## 6. Apps and Packages — search.nixos + Homebrew Are the Registry

**Approved: Auto `omanix add` (primary UX). No custom packaging if nixpkgs or brew already has it. Help the user get apps quickly/reliably and remove them just as quickly.**

`omanix add` / `omanix remove` are declarative wrappers that edit `flake.nix` for you:

```bash
omanix add ripgrep          # 1. nix search nixpkgs ripgrep → found → add pkgs.ripgrep to environment.systemPackages, nix flake lock + rebuild
omanix add google-chrome    # 1. nix search miss, 2. brew search cask found → add to homebrew.casks = [ "google-chrome" ], rebuild
omanix add my-pomodoro      # miss both → error: "not in nixpkgs nor brew — add as flake input: inputs.my-pomodoro.url = ..."
omanix remove ripgrep       # edit flake to delete entry, rebuild, next generation drops it; rollback restores it
omanix search ripgrep       # nix search nixpkgs ripgrep && brew search ripgrep
```

Implementation: `bin/lib/omanix-add.sh`:

1. `nix search --json nixpkgs ^$name$` (check exact, then substring)
2. `brew search --cask $name` / `brew search $name`
3. Edit `flake.nix` via `nix edit` helper that inserts into the correct list (`environment.systemPackages` vs `homebrew.casks` vs `homebrew.brews`) — never duplicate what is already there.
4. Run `nix flake check` dry; on failure revert edit and print error.
5. `omanix rebuild` (which is `darwin-rebuild switch`).

**Conventions for contributors:**
- Before adding to `packages/`, you must paste `nix search` and `brew search` miss in the PR description.
- `environment.systemPackages` vs `home.packages`: system-wide CLI → `darwin`, user dotfiles/tools → `home`. When in doubt, `home.packages`.

---

## 7. Pristine Uninstall Contract — Full Pristine

**Approved: Full pristine.** Every file Omanix creates is inside `/nix/store` (symlinked) or `homebrew` (managed). Uninstall is tested, not documented, and removes *all* casks Omanix added (tracked via `flake.nix`):

```bash
/nix/nix-installer uninstall
rm -rf ~/.config/omanix
# launchd plists from launchd.user.agents / launchd.daemons are removed by nix-darwin uninstall
# /Applications/Pomodoro.app symlinks from mkOmanixApp are removed by activation's cleanup
brew uninstall --cask google-chrome  # if user wants to drop brew casks Omanix added — or use `omanix uninstall --with-brew`
```

Guarantees:
- No `~/Library/LaunchAgents/org.nixos.*` leftover — only `launchd.user.agents` did it, and `darwin-uninstall` cleans.
- No `~/.config/hypr/*.lua` residue — they were store symlinks. `home-manager.backupFileExtension = "backup"` restores pre-Omanix files.
- Swift apps (`/Applications/Pomodoro.app`) vanish because they were symlinks to store.
- Homebrew casks use `onActivation.cleanup = "uninstall"` — removing from flake + rebuild uninstalls the cask; full `omanix uninstall` can `brew uninstall` all casks we added (tracked in `flake.nix` `homebrew.casks` list).

`tests/pristine` does `switch` → `add ripgrep` → `add google-chrome` → `switch` → `uninstall` and asserts no `/nix`, no `LaunchAgents`, no `/Applications/Omanix*`.

---

## 8. Homebrew Boundary — What Goes Where

Pragmatic, enforced by review:

| Type | Owner | Example |
|---|---|---|
| CLI, LSP, compiler, DB, fonts | `nixpkgs` | `ripgrep`, `starship`, `postgresql_16`, `ttf-jetbrains-mono-nerd` |
| Signed GUI `.app` | `homebrew.casks` | `google-chrome`, `vscode`, `slack` |
| Brew formula not in nixpkgs | `homebrew.brews` | `ta-lib` (if `pkgs.ta-lib` missing) |
| Language runtimes | **Neither mise nor brew** | `pkgs.ruby_3_3`, `pkgs.python313` |

New `brews`/`casks` need comment ` # not in nixpkgs: <reason>`. `brew install` outside activation is CI failure.

---

## 9. Config Injection — No One Opens a .config to Understand

`default/themed/*.tpl` is not a user surface. User never edits `foot/foot.ini` or `aerospace.toml`. They set `programs.foot.settings` or `desktop.aerospace` options that `lib/themed.nix` renders.

**Approved: Forbid duplicates (strict).** `xdg.configFile."...".text` is a privileged escape hatch for truly novel software with no Omanix abstraction. `tests/cli` **fails** (not warns) if a raw config duplicates an existing `omarchy`/`desktop` option. If you need a raw file to make it work, add the typed option — don't document a raw edit.

---

## 10. Naming & Style

Inherited from `omarchy-mac/AGENTS.md:14-23` + Nix:

- Bash (`bin/omanix`, shims): `#!/bin/bash`, two-space indent, `[[ ]]`/`(( ))`, quote spaces.
- Nix: `nixfmt`, two-space, `mkOption` always `type` + `default` + `description`.
- Commands: keep `omarchy-*` prefix where Omarchy name exists, new Omanix-only are `omanix-*` (with `omanix-*` shim if renaming).
- Menu: `default/omarchy/omarchy-menu.jsonc` stays JSONC; no `aliases` on new entries.

---

## 11. Testing

```bash
nix flake check
bin/omanix commands --check
for f in bin/*; do bash -n "$f"; done
./tests/cli && ./tests/shell && ./tests/pristine
darwin-rebuild check --flake .#$(hostname)
```

New widget/app needs a test that it appears after rebuild and vanishes after `enable = false` + rebuild, and survives `pristine` uninstall. New `add` routing needs a `search` golden.

---

## 12. Vendoring & Sync

`themes/`, `config/`, `default/`, `shell/` vendored from `../omarchy-mac` at pinned rev (`inputs.omarchy-mac.url`). Sync PRs: `nix flake lock --update-input omarchy-mac` + `rsync -a --delete` + `nix flake check` (fails if new `{{ var }}` has no `themed.nix` mapping). No hand edits to vendored trees.

---

## 13. Deletion List

Hard deletes on Darwin (shim → `not available on Darwin`):

`omarchy-mac-setup`, `omarchy-system-btrfs-migrate`, `omarchy-snapshot`, `omarchy-refresh-pacman*`, `omarchy-refresh-plymouth/limine`, `omarchy-theme-set` (runtime), `omarchy-plugin-add` (runtime git), `omarchy-pkg-*` (→ `nix`), `omarchy-mise-*`, `omarchy-hw-nvidia*`, etc. Append-only; removing requires `tests/cli` update.
