# Omanix Conventions — How We Build

Conventions are the agreements that let principles and philosophies turn into code without bikeshedding. Follow them, or propose a patch to change them.

---

## 1. Folder Structure — Simple for Green Users, Scales to Complexity, Ready for Linux

This is the **approved** tree. Beginner sees `configuration.nix`; complexity scales via `hosts/` and `modules/`; Linux is a future `system = "x86_64-linux"` branch already stubbed.

```
omanix/                              # flake root — cloned to ~/.omanix (beginner: you edit configuration.nix)
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
│   │   ├── pomodoro.nix             # uses lib/mkWidget: sketchybar item + launchd timer
│   │   └── clock.nix
│   ├── apps/                        # Swift apps on mac, GTK/Electron on linux — via lib/mkApp, appear as native apps
│   │   ├── store/                   # Omanix Store — SwiftUI on mac (GTK on linux) via lib/mkApp, itself a widget (omanix.widgets.store)
│   │   │   └── Sources/             # ContentView.swift, StoreView.swift — built to /Applications/Omanix Store.app
│   │   └── pomodoro-app/
├── lib/
│   ├── mkSystem.nix                 # if system == "aarch64-darwin" or "x86_64-darwin" → darwinSystem else → nixosSystem
│   ├── mkWidget.nix                 # { name, sketchybarConfig|hyprlandConfig, launchdOrSystemd, swiftOrGtkSrc } → module + derivation
│   ├── mkApp.nix                    # { name, bundleId/desktopFile, src } → /Applications/*.app or /usr/share/applications
│   └── themed.nix                   # colors.toml + *.tpl → store (user never touches tpl)
├── themes/                          # Omanix themes (colors.toml) — build-time only
├── config/ + default/ + shell/      # Omanix theme sources — read-only, compiled by lib
├── overlays/                        # git-ignored, AI/agent preview drop-ins: overlays/pomodoro/{default.nix, Sources/*.swift} → `omanix rebuild --preview` (impure, no generation)
├── skills/
│   └── omanix/
│       └── SKILL.md                 # machine-readable schema for agents: mkWidget/mkApp contract, theme tokens, lint (statix/nix fmt), preview→commit flow
├── bin/
│   └── omanix                       # install | rebuild | rebuild --preview | generations | add <pkg> | remove <pkg> | search <pkg> | store → search.nixos/brew routing
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

**Vendored read-only:** `themes/`, `config/`, `default/`, `shell/` at pinned rev. Changes from upstream sync PRs only.

**Daily-driver diff target:** Your daily `config/flake.nix` + `config/home.nix` should diff cleanly to `configuration.nix` + `home.nix` one-to-one.

---

## 2. Flake Contract — Distro Clone, No Raw Config

`flake.nix` is the machine. The user never opens a `.toml`/`.tpl`/`.config` to make Omanix work — they set Nix options:

```nix
{
  # ~/.omanix/flake.nix — the only file you edit
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
2. `git clone` → `~/.omanix`
3. Prompt `hostname`/`username` and `sed` into `darwinConfigurations."<hostname>"` + `system.primaryUser`/`users.users`
4. `darwin-rebuild switch --flake .#<hostname>`

`omanix` binary:

```bash
#!/bin/bash
case "$1" in
  rebuild) shift; [[ "$1" == --rollback ]] && exec sudo darwin-rebuild --rollback || exec sudo darwin-rebuild switch --flake ~/.omanix#$(scutil --get LocalHostName) "$@" ;;
  generations) darwin-rebuild --list-generations ;;
  update) nix flake update ~/.omanix && omanix rebuild ;;
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
omanix.bar = { position = "top"; transparent = false; layout.left = ["omanix.menu" "omanix.workspaces"]; };
```

Not via `default/themed/*.tpl`. `shell/` QML is never executed; its tokens are the reference for SketchyBar plugin reimplementation in `modules/desktop/sketchybar/plugins/*.nix`.

---

## 5. Widgets and Apps Are Nix Derivations — Not Bash Plugins

This is the **pomodoro contract**. Community lets someone AI-generate a pomodoro bash plugin and it appears as a widget. Omanix lets someone AI-generate a pomodoro *Nix widget* and it appears as if you installed a Mac app — because you did (a Nix-built one).

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
rm -rf ~/.omanix
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

`themes/`, `config/`, `default/`, `shell/` curated Omanix themes at pinned rev (`inputs.omarchy-mac.url`). Sync PRs: `nix flake lock --update-input omarchy-mac` + `rsync -a --delete` + `nix flake check` (fails if new `{{ var }}` has no `themed.nix` mapping). No hand edits to vendored trees.

---

## 13. Deletion List

Hard deletes on Darwin (shim → `not available on Darwin`):

legacy Linux-only `omarchy-*` commands (setup, snapshot, pacman, plymouth, etc.) — removed on Darwin; see `bin/shims/` — append-only

---

## 14. Omanix Store — GUI for Green Users, Built as a Widget, Enabled by Default

The Store is `modules/apps/store/` → `lib/mkApp` SwiftUI (mac, `mkApp` GTK on linux), `omanix.widgets.store.enable = true` **by default** in `configuration.nix` (approved: welcoming). It *is* a widget, so it follows all principles: derivation in `/nix/store`, `launchd` plist via `launchd.user.agents`, `/Applications/Omanix Store.app` symlink, removed by `omanix uninstall` (or `omanix.widgets.store.enable = false` + rebuild for power users).

**UX contract:**
- **Browse:** Nix packages (`nix search` cached JSON) + brew casks/brews + `omanix.widgets` gallery + `omanix.theme` picker. Search box debounces, shows `search.nixos.org` description + `brew info` cask.
- **Install/Remove:** Buttons call `lib/omanix-add.sh` / `lib/omanix-remove.sh` helpers that edit `configuration.nix` (adds `environment.systemPackages` or `homebrew.casks`), run `nix flake check` dry, show diff preview, then `omanix rebuild` with progress bar. No terminal. On failure, shows `nix` log + `Rollback` button.
- **Widgets:** Toggles `omanix.widgets.pomodoro.enable` etc., previews live via `sketchybar --reload` (mac) / `quickshell ipc` (linux) without full rebuild — `Store` writes to `overlays/store-preview.nix` then `omanix rebuild --preview`.
- **OS settings:** Sliders for `system.defaults.dock`, `desktop.aerospace.gaps`, Touch ID toggle — all `omanix.*` options, never raw `defaults write`.
- **Entry points:** `Super → Omanix Store`, `open -a "Omanix Store"`, `omanix store` CLI. Green user never types `omanix add`.

**Contributor rule:** Store edits `configuration.nix` via structured helpers (`nix edit`-like `yq` for Nix), not `echo` or `sed`. All Store-initiated changes must be `omanix rebuild --rollback`able in 30s and appear as a `git diff` in `~/.omanix`.

---

## 15. AI-Agent-Ready — Skill + Two-Phase Build (Preview → Commit), Mac-Native IPC

Omanix is ready for `Claude Code`/`OpenCode` to drop a pomodoro that *just appears*, without the agent writing bash to `~/.config` or `/nix/store`.

**Skill — `skills/omanix/SKILL.md` (auto-installed, linters ready):**
- Installed by `home.file."~/.omanix/skills/omanix/SKILL.md"` and symlinked to `~/.claude/skills/omanix/SKILL.md` + `~/.opencode/skills/omanix/SKILL.md` on activation. **Approved:** `bin/omanix install` auto-installs `statix` + `nixfmt` + `nixd` into agent PATH ( `nix develop` also provides them) — agents lint without manual setup.
- Contains: typed contract `lib/mkWidget { name, sketchybarConfig|hyprlandConfig, launchdOrSystemd, swiftOrGtkSrc, dependencies, theme }` + `lib/mkApp`, theme tokens `config.lib.omanixTheme.colors.*`, `omanix.widgets.*` examples (pomodoro `Sources/ContentView.swift` on mac, `widget.qml` on linux), lint commands (`statix check`, `nix fmt`, `nix-instantiate --parse`), and the two-phase flow.
- Agents must run `statix` + `nix fmt` + `nix-instantiate --parse overlays/<name>/default.nix` before any `omanix rebuild`.

**Two-phase build — same delight as friend's map, mac-native, now with permanent impure allowed:**
1. **Draft (no build):** Agent writes `~/.omanix/overlays/pomodoro/{default.nix, Sources/ContentView.swift}` (or `widget.qml` on linux) — `overlays/` is `git-ignored` by default, impure, not in `flake.lock`.
2. **Preview (impure, instant, no generation):** `omanix rebuild --preview` — `configuration.nix` imports `overlays/*/default.nix` via `builtins.readDir ../overlays` (impure, `lib/mkSystem` handles branch), builds `/nix/store/...-pomodoro`, hot-reloads `sketchybar --reload` + `launchctl load` (mac) / `quickshell ipc` + `systemctl --user daemon-reload` (linux) via IPC. Widget appears, theme-injected, no generation bump.
3. **Commit OR keep impure (user chooses, approved: allow permanent impure):**
   - **Pure commit (default, tracked, Store-visible):** `omanix add pomodoro --from-overlay overlays/pomodoro` moves overlay to `inputs.pomodoro` + `omanix.widgets.pomodoro.enable` in `configuration.nix`, `nix flake lock --update-input`, `nix flake check`, `omanix rebuild` (pure, new generation). `overlays/` cleared. Green user sees toggle in Store.
   - **Permanent impure (fast, no lock, instant, no generation):** Keep `overlays/pomodoro/` and `omanix rebuild` (no `--preview` flag needed after approval) — `configuration.nix` keeps importing `overlays/*` impurely every rebuild, no `flake.lock` entry, no generation beyond overlay file existence. Agent documents `overlays/pomodoro/README.md: impure — delete folder to remove`. Allowed for throwaway AI experiments; `omanix uninstall` still deletes `overlays/` so pristine holds, but `rollback` is `rm -rf overlays/pomodoro && omanix rebuild --preview`.
4. **Undo:** Pure: `omanix rebuild --rollback` or `omanix remove pomodoro`; impure: `rm -rf overlays/pomodoro && omanix rebuild --preview`.

**Why not friend's *only* `--impure` forever:** We keep preview speed but make persistence a choice — pure for teams/Store visibility/rollback, impure for rapid AI iteration where lock churn is unwanted. Linters are ready day one, so agent never writes invalid Nix. Linux path reuses same `SKILL.md` but picks `qmlSrc` + `systemd` branch — `lib/mkWidget` abstracts `sketchybar` vs `quickshell`.

**Contributor rule for agent authors:** Use `pkgs` deps (`pkgs.libnotify`, `pkgs.mpv`), not `which mpv`; use `${config.lib.omanixTheme.colors.accent}`, not hardcoded `#7aa2f7`; never write to `/nix/store` or `~/.config` outside `overlays/`.

---

## 16. Local AI (Qwen) for Light Tasks — Tiny Skill, Constrained Tools, Offline

Frontier handles heavy (full Swift `mkApp`); local `qwen2.5:7b`/`qwen3:8b` via `Ollama` handles not-heavy (theme, `omanix add`, simple `mkWidget` template fill) offline, private, <2s.

**Model:** `ollama` daemon from `config/ollama.plist` + `config/nix/ollama.plist` (already in daily driver). **Approved: opt-in only** — `omanix setup local-ai` does `ollama pull qwen2.5:7b` (default) or `qwen3:8b` if RAM ≥16GB only when user runs it; installer does not prompt or pull by default. Model lives in `~/.ollama` (outside `/nix`, pruned by `omanix uninstall --with-ollama` only if user opts). `ollama` is `launchd.user.agents.ollama` on mac, `systemd --user` on linux — same `modules/services/ollama.nix`.

**Mini skill — `skills/omanix/mini-SKILL.md`:** Installed alongside full `SKILL.md` to `~/.omanix/skills/omanix/mini-SKILL.md` and `~/.claude/skills/omanix/` for visibility, but frontier agents ignore it. It is ~2KB JSON schema:

```json
{ "type": "object", "properties": { "action": {"enum": ["setTheme","toggleWidget","addPackage","mkWidget"]}, "theme": {"enum": ["tokyo-night","catppuccin"]}, "widget": {"type": "string"}, "package": {"type": "string"} } }
```

+ 2 few-shots: `{"action":"setTheme","theme":"matte-black"}` → `omanix.theme = "matte-black"`; `{"action":"mkWidget","widget":"pomodoro"}` → `lib/mkWidget { name="pomodoro"; sketchybarConfig={icon="󰔟";}; launchdConfig={StartInterval=60;}; }` (template fill, approved). No full Swift/QML `lib/mkApp` generation — local fills a fixed `mkWidget` template only, frontier does full Swift.

**Tools (constrained):** Local agent PATH has only `omanix add|remove|search`, `omanix widgets toggle`, `omanix theme set`, `nix fmt`, `statix check`. No `swift build`, no `xcodebuild`, no raw `echo` to `configuration.nix` — it calls `omanix add` helpers that edit `configuration.nix` structured, same as Store. If `statix` fails, local falls back to `omanix ask --local --dry-run` showing the `configuration.nix` diff, never writes.

**Entry points:** `omanix ask --local "make it darker"` (CLI), Store's `Ask (offline)` bar (GUI), `Super → Ask → Offline`. All route to `ollama run qwen2.5:7b --skill mini-SKILL.md`. Frontier is `omanix ask "make pomodoro app"` → `claude` with full `SKILL.md`.

**Why tiny:** Qwen 7B hallucinates on long Nix + Swift. Mini skill keeps context <1k tokens, JSON-enforced, and the preview → commit still applies — local writes `overlays/pomodoro-mini/{default.nix}` (simple `mkWidget` fill), `omanix rebuild --preview` hot-reloads, same Store toggle appears. Frontier skill stays full for heavy tasks.

**Contributor rule for local:** If you add a new `omanix.widgets.*` option, add its JSON enum to `mini-SKILL.md` and a third few-shot, or local won't see it.
