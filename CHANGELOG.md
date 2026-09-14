# Changelog

## 0.3.0-dev (2026-09-14)

### Native macOS menu bar (spacebar removed); Omabar archived in ice/

- **Spacebar removed:** the external `spacebar` daemon, the `omanix.spacebar.*` options, and `modules/darwin/spacebar.nix` (nix-darwin `services.spacebar`) are gone from the build — the menu bar is now the native macOS menu bar.
- **`_HIHideMenuBar` now false:** the native macOS menu bar is shown (no custom bar daemon draws over it).
- **Archived in `ice/`:** the old in-app Omabar plugin-host code is under `ice/omabar/` (restored from commit 8991666), and `spacebar.nix` under `ice/spacebar/` — none of it is in the build chain.
- **Docs/tests updated:** themes.md/conventions/principles/philosophies and the agent skill now describe the native menu bar; tests updated.

### Spacebar replaces the in-app Omabar module

- **Spacebar daemon:** the menu bar is now the external `spacebar` daemon (`modules/darwin/spacebar.nix` → nix-darwin `services.spacebar`), fully configured from new `omanix.spacebar.*` options (enable, position, display, height, showClock, clockFormat, showPower, showTitle, showSpaces, showDnd, paddingLeft/Right, spacingLeft/Right, textFont, iconFont). Theme colors map to spacebar's `0xffRRGGBB` form (`background_color`/`foreground_color` from `background`/`foreground`, icon colors from `accent`); bar font is `font-awesome` installed via `fonts.packages`; native Control Center clock/battery hidden when the corresponding items are shown.
- **Omabar deleted:** `Modules/Omabar/`, `Modules/Plugins/`, `Views/OmabarView.swift`, `Modules/Desktop.swift`, the SysEvents monitors (BarState, BatteryMonitor, ClockTicker, CoreAudioVolumeMonitor, WifiMonitor) and `--omabar` mode removed. `EventBus.swift` trimmed to window events only (Omatiles uses them). `omanix.omabar.*` options, CLI setters, and `--omabar` launchd agent (`om.omanix.omabar`) all removed; the CLI/`spacebar` schema and GUI widget now use `omanix.spacebar.*`.
- **Docs/tests:** themes.md tables, conventions/principles/philosophies, and the agent skill updated to the spacebar architecture; two-way + behavior test suites updated to the spacebar state.

### Flake-source integrity: state.nix tracked again; overlays preview fixed

- **`state.nix` is tracked again.** Nix flakes copy ONLY git-tracked files into the build source — the 0.2.x "gitignore state.nix" approach silently removed the file `configuration.nix` imports, so every rebuild failed with `path '/nix/store/…-source/state.nix' does not exist`. `state.nix` is now a tracked-but-machine-written file: an empty committed template provides the baseline, `state set`/`prune`/`reset` rewrite the working tree copy (which builds pick up), and `omanix update` autostashes + restores machine edits across pulls. `version` stays ignored (read by the update script only, never evaluated).
- **`overlays/` previews actually reach the build now.** The gitignored `overlays/` dir was invisible to every eval (`builtins.pathExists ../overlays` = false inside the store copy), so `--preview` and impure overlays silently did nothing. `omanix rebuild` now stages `overlays/` into the git index for the eval (the only way ignored files enter the flake source copy), then unstages it afterwards, so throwaway previews stay throwaway.
- **`omanix update` no longer conflicts on machine-owned files:** `git pull --rebase --autostash` covers machine edits to `state.nix`, `state prune` drops stale option keys after the pull, and the script aborts with instructions instead of rebuilding if any resolution is still pending.
- Fixed remaining `ensure_state` → `ensure` typos in `libexec/omanix-rebuild.sh` + `libexec/install.sh`.
- tests/pristine gains a flake-source guard: `state.nix` must be tracked and no untracked `.nix` files may exist — the exact failure class that caused the state.nix incident.

## 0.2.0-dev (2026-08-29)

### Native desktop modules — no external bar/tiler

- **Omabar (rewrites SketchyBar):** native SwiftUI menu bar inside the Omanix app (`Modules/Omabar/` — `OmabarManager` `NSPanel`, `OmabarContentView`, `OmabarModel`). Launched by `launchd` agent `om.omanix.omabar` → `Omanix.app --omabar`; hides the native macOS menu bar, registers the bar Nerd Font, themed live from `~/.config/omanix/theme.json`. Options: `omanix.omabar.*` (position, height, transparent, blur, style, colorScheme, showClock/showBattery/showVolume/showWifi).
- **Omatiles (rewrites AeroSpace):** native SwiftUI/AppKit window tiling inside the Omanix app (`Modules/Omatiles/` — `OmatilesEngine`, `OmatilesLayouts`). Launched by `launchd` agent `om.omanix.omatiles` → `Omanix.app --omatiles`; layouts tiles/columns/rows/accordion, gaps, global bindings (⌘⌥T/J/K/L), watch mode, floating apps via the Accessibility API. Options: `omanix.omatiles.*` (enable, layout, gapInner, gapOuter, bindings, watch, floatingApps).
- **AeroSpace + SketchyBar deleted:** removed `modules/darwin/desktop.nix`, `lib/hypr-to-aerospace.nix` mapping, and all sketchybar/aerospace file generation. Desktop.nix split into `modules/darwin/omabar.nix` + `omatiles.nix`.
- **Semantics change:** Omatiles options live under `omanix.*` as direct options (not `omanix.desktop.aerospace.*`); hot-reload is per-module live apply, not `sketchybar --reload`.
- **GUI:** new `Views/OmabarView.swift` + `Views/OmatilesView.swift` settings pages, `ThemesView` bar-appearance controls rewired to `omanix.omabar.*`, module modes in `OmanixApp.swift` (`--omabar`/`--omatiles`).
- **Docs:** themes.md, principles.md, conventions.md, philosophies.md rewritten to the native-module architecture.

## 0.1.0-dev (2026-08-25)

### Scaffolded

- **Flake foundation:** `flake.nix` with pinned nixpkgs/nix-darwin/home-manager, `lib/mkSystem.nix` for darwin/linux branching
- **Core system:** Nix daemon, Touch ID, system.defaults, fonts, homebrew (pristine)
- **Theme engine:** `lib/themed.nix` reads `themes/*/colors.toml`, renders templates, `omanix.theme` enum
- **Desktop:** AeroSpace + SketchyBar stubs, `lib/hypr-to-aerospace.nix` keybinding mapping
- **Package fabric:** `omanix add/remove/search` CLI routing nixpkgs → brew
- **Widget system:** `lib/mkWidget.nix` + `lib/mkApp.nix` SDK, pomodoro + clock widgets
- **Store GUI:** Placeholder SwiftUI app, `omanix.widgets.store.enable = true` by default
- **AI integration:** `skills/omanix/SKILL.md` (frontier) + `mini-SKILL.md` (local Qwen), ollama service stub
- **Tests:** `tests/cli` (bash+nix syntax), `tests/shell` (theme golden), `tests/pristine` (dry run)
- **CI:** `.github/workflows/check.yml` for aarch64 + x86_64 darwin runners
