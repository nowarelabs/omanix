# Changelog

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
