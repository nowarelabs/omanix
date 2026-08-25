# Changelog

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
