# Omanix Themes — Distribution System

> **Build-time purity.** You set `omanix.theme = "tokyo-night"` — Nix renders `Ghostty`, `SketchyBar`, `AeroSpace` colors. You never edit `colors.toml` or `.tpl` by hand. See `principles.md:3`.

---

## Available Themes (13)

| Theme | Mode | Accent | Background | Style | VS Code |
|---|---|---|---|---|---|
| `omanix` | light | `#0A7CFF` | `#FBFBFC` | **Signature Omakase** — OC light, matches GUI | `vscode.omanix-light` |
| `tokyo-night` | dark | `#7aa2f7` | `#1a1b26` | Tokyo deep blue | `enkia.tokyo-night` |
| `catppuccin` | dark | `#89b4fa` | `#1e1e2e` | Pastel mocha | `catppuccin.catppuccin-vsc` |
| `gruvbox` | dark | `#fe8019` | `#282828` | Warm retro 1970s | `jdinhlife.gruvbox` |
| `everforest` | dark | `#a7c080` | `#2b3339` | Forest green, low contrast | `sainnhe.everforest` |
| `kanagawa` | dark | `#7e9cd8` | `#1f1f28` | Japanese ukiyo-e wave | `rebobos.kanagawa` |
| `rose-pine` | dark | `#ebbcba` | `#191724` | Muted rosé | `mvllow.rose-pine` |
| `nord` | dark | `#88c0d0` | `#2e3440` | Arctic frost | `arcticicestudio.nord-visual-studio-code` |
| `dracula` | dark | `#bd93f9` | `#282a36` | Vampire purple | `dracula-theme.theme-dracula` |
| `solarized-dark` | dark | `#268bd2` | `#002b36` | Solarized Ethan Schoonover | `solarized.solarized-dark` |
| `one-dark` | dark | `#61afef` | `#282c34` | Atom One Dark | `zhuangtongfa.material-theme` |
| `matte-black` | dark | `#d4d4d4` | `#0a0a0a` | Pure OLED black | `matte-black` |
| `horizon` | dark | `#fab795` | `#1c1e26` | Sunset horizon | `jolsten.horizon-theme` |

Preview: `ls themes/<name>/preview.png` and `cat themes/<name>/colors.toml`.

---

## Quick Start

```nix
# ~/.omanix/configuration.nix — the only file you edit
{ pkgs, ... }: {
  omanix.host = "my-mac";
  omanix.user = "yourname";
  omanix.theme = "kanagawa";          # pick any from above
  omanix.bar = {
    position = "top";                 # top | bottom (flows around notch)
    transparent = false;              # true = bar bg transparent
    blur = false;                     # blur behind bar (macOS vibrancy)
    blurRadius = 50;                  # 0-100
    style = "default";                # default | minimal | glass | modern
    colorScheme = "auto";             # auto | dark | light (follows theme mode)
  };
}
```
Then: `omanix rebuild` — `Ghostty` + `SketchyBar` + widgets reload with new colors.

**Store GUI:** `Super → Omanix Store → Theme picker` shows live preview, no terminal.

---

## Color Customization (Overrides)

You can override any palette entry without forking a theme. Overrides merge on top of `themes/<name>/colors.toml` via `lib/themed.nix:getThemeColors`.

```nix
{
  omanix.theme = "tokyo-night";
  # Option A (preferred):
  omanix.themeOverrides.accent = "#FF00FF";
  omanix.themeOverrides.background = "#0a0a12";
  # Option B (alias):
  omanix.theme.colors.accent = "#FF00FF";
}
```

All 24 keys overrideable: `accent`, `background`, `foreground`, `selection`, `muted`, `red`, `green`, `blue`, `yellow`, `cyan`, `magenta`, `orange`, `brown`, `bright_red`, etc. See `themes/tokyo-night/colors.toml` for full schema. `null` means use theme default.

**When to override vs new theme:** One-off accent tweak → override. Sharing a palette → new `themes/<name>/` (see below).

---

## Bar Styling

| Option | Values | Effect |
|---|---|---|
| `omanix.bar.position` | `top` / `bottom` | Bar placement (SketchyBar `position`) |
| `omanix.bar.transparent` | `bool` | `true` → `0x00000000` bar, desktop shows through |
| `omanix.bar.blur` | `bool` | Vibrancy blur (`blur_radius`) — best with transparent |
| `omanix.bar.blurRadius` | `0-100` | Blur strength |
| `omanix.bar.style` | `default` `minimal` `glass` `modern` | `glass` = transparent+blur+12px radius; `modern` = 9px radius; `minimal` = no borders/separators |
| `omanix.bar.colorScheme` | `auto` `dark` `light` | `auto` reads `themes/*/colors.toml:mode`; `dark`/`light` force `NSGlobalDomain.AppleInterfaceStyle` |

Examples:
- Glass: `style = "glass"` (implies `transparent = true`, `blur = true`, `blurRadius = 50`)
- OLED: `theme = "matte-black"` + `bar.transparent = false`
- Minimal top: `style = "minimal"` + `position = "top"`

---

## How It Works (Omarchy Parity)

Omarchy uses `~/.local/state/omarchy/current/theme/*.conf` imperative distribution. Omanix mirrors it **purely at build time**:

```
themes/<name>/colors.toml  ─┐
                             ├─► lib/themed.nix:readTheme + getThemeColors (merge overrides)
                             │         │
default/themed/*.tpl (future)─┘         ├─► ghostty/config (xdg.configFile."ghostty/config")
                                        ├─► sketchybar/colors.sh (OMANIX_* vars)
                                        ├─► sketchybar/sketchybarrc (bar, blur, position)
                                        ├─► aerospace/theme.toml (accent borders)
                                        ├─► omanix/theme.json (Store + widgets)
                                        └─► ~/.config/omanix/theme.json (runtime reload)

modules/theme/theme.nix — writes all above via home-manager xdg.configFile
modules/darwin/desktop.nix — consumes colors for bar/borders
modules/widgets/*.nix — source OMANIX_ACCENT etc. via themed.getThemeColors
```

**Key file:**
- `lib/themed.nix:8` `readTheme` — `builtins.fromTOML (builtins.readFile ../../themes/${name}/colors.toml)`
- `lib/themed.nix:11` `getThemeColors` — `base // overrides` (both `omanix.themeOverrides` and `omanix.theme.colors` supported)
- `lib/themed.nix:60` `ghosttyConfig` — generates Ghostty `background/foreground/palette`
- `lib/themed.nix:85` `sketchyBarColors` — generates `colors.sh` with `OMANIX_*`
- `modules/theme/theme.nix:20` — propagates to `home-manager.users.<user>.xdg.configFile` + `theme.json` + `activationScripts`
- `modules/darwin/desktop.nix:12` — SketchyBar `sketchybarrc` templated with `color`, `blur_radius`, `corner_radius`, `position`

No `~/.config` is ever hand-edited (principles.md:3). `omanix rebuild --rollback` reverts theme in <30s via Nix generations.

---

## Adding a New Theme

1. **Create directory:** `mkdir -p themes/<my-theme>/backgrounds`

2. **Write `colors.toml`** — 25 keys, same schema as existing (copy `themes/tokyo-night/colors.toml`):

```toml
mode = "dark"   # or "light"

accent = "#7aa2f7"
selection = "#292e42"
muted = "#414868"

background = "#1a1b26"
dark_background = "#13141c"
darker_background = "#0e0e14"
lighter_background = "#24283b"

foreground = "#a9b1d6"
dark_foreground = "#565f89"
light_foreground = "#b4bee6"
bright_foreground = "#c0caf5"

red = "#f7768e"
yellow = "#e0af68"
orange = "#eb927b"
green = "#9ece6a"
cyan = "#449dab"
blue = "#7aa2f7"
magenta = "#ad8ee6"
brown = "#75493d"

bright_red = "#ff7a93"
bright_yellow = "#ff9e64"
bright_green = "#b9f27c"
bright_cyan = "#0db9d7"
bright_blue = "#7da6ff"
bright_magenta = "#bb9af7"
```

Required: all keys must be `mode` or `#RRGGBB`. Validated at `nix flake check` time via `builtins.fromTOML`.

3. **Optional supporting files** (for Store parity with Omarchy):
   - `icons.theme` — e.g. `Yaru-blue`
   - `neovim.lua` — plugin spec
   - `vscode.json` — `{ "name": "...", "extension": "..." }`
   - `backgrounds/*.jpg` — wallpapers
   - `preview.png` — 16:9 screenshot

4. **Register enum:** Add name to `modules/core/options.nix:18` `omanix.theme` enum (e.g. `"my-theme"`).

5. **Check:** `nix flake check` and `nix-instantiate --parse themes/<my-theme>/colors.toml` (no need to rebuild yet).

6. **Use:** `omanix.theme = "my-theme";` + `omanix rebuild`.

**Community submission:** PR with `themes/<name>/colors.toml` + preview + `vscode.json` + enum entry. Do not hand-edit `lib/themed.nix` — new colors automatically propagate to Ghostty/SketchyBar/widgets.

---

## Themed Applications

| App | Config Path (generated) | Source | Colors Used |
|---|---|---|---|
| **Ghostty** | `~/.config/ghostty/config` | `lib/themed.nix:ghosttyConfig` | `background`, `foreground`, `accent`, `selection`, `red`-`magenta` palette 0-15 |
| **SketchyBar** | `~/.config/sketchybar/colors.sh` + `sketchybarrc` | `lib/themed.nix:sketchyBarColors` + `modules/darwin/desktop.nix` | `background`/`transparent`, `foreground`, `accent`, `muted`, `selection`, `blurRadius`, `position` |
| **AeroSpace** | `~/.config/aerospace/theme.toml` | `modules/darwin/desktop.nix` | `accent` (active border), `muted` (inactive), `gaps` |
| **Widgets** | `~/.config/sketchybar/plugins/*.sh` | `modules/widgets/*.nix` via `themed.getThemeColors` | `accent` (icon), `foreground` (label) |
| **System** | `NSGlobalDomain.AppleInterfaceStyle` | `modules/theme/theme.nix` | `mode` → `Dark` / `null` |
| **Store/GUI** | `~/.config/omanix/theme.json` | `modules/theme/theme.nix` | Full palette JSON for SwiftUI |

Future Linux: same `lib/themed.nix` drives `Hyprland` borders + `Quickshell` (see `modules/linux/desktop.nix`).

---

## Per-Application Overrides

Global `omanix.themeOverrides` affects all apps. For per-app divergence (e.g. keep bar on `tokyo-night` but terminal on pure black):

```nix
{
  omanix.theme = "tokyo-night";
  omanix.perApp.ghostty.background = "#000000"; # alias omanix.theme.perApp.ghostty.background
  omanix.perApp.ghostty.accent = "#ff00ff";
  omanix.perApp.sketchybar.background = "#1a1b26"; # bar stays readable
  omanix.perApp.aerospace.accent = "#7aa2f7";      # window borders
}
# CLI:
# omanix theme per-app ghostty background "#000000"
```

Resolution: `base = themes/<name>/colors.toml` → `// omanix.themeOverrides` → `// omanix.perApp.<app>` (via `lib/themed.nix:getAppColors`, spec alias `theme.perApp` also read if set). Ghostty uses `ghostty` delta, SketchyBar/AeroSpace use theirs, widgets use global.

---

## Theme Transitions

Animated switches keep the desktop feeling native (Omarchy provides no animation on Linux).

```nix
omanix.transition.enable = true;   # default true — alias omanix.theme.transition.enable
omanix.transition.duration = 200;  # 0-1000 ms
omanix.transition.type = "crossfade"; # crossfade | slide | none
# CLI: omanix theme transition on|off
```

Implementation: `modules/theme/theme.nix` writes `~/.config/omanix/theme-transition.sh` (uses `sketchybar --animate sin <frames>`). `crossfade` fades bar to transparent → `sketchybar --reload` → fade back; `slide` animates `y_offset=-32 → 0`; `none` instant. Disable (`enable = false`) for instant cut (useful for screenshots/tests). Nix path is `omanix.transition` because `omanix.theme` is a string enum (cannot nest); spec alias `theme.transition` also honoured. All are `<30s` rollbackable via generations.

---

## Store Integration

`Super → Omanix Store → Themes` (12 cards) reads `vm.themes` (hardcoded from `themes/*/colors.toml`, bridged via `OColor(hex:)`) and `store.currentThemeId()` (`~/.config/omanix/theme.json` → `configuration.nix`). Tap **Select** → `store.setTheme(id)` → `needsRebuild` banner → **Rebuild**. Bar appearance controls (`position`/`style`/`transparent`/`blur`) live in the same page and write `omanix.bar.*`. See `modules/apps/gui/Views/ThemesView.swift:12` and `ViewModels/OmanixViewModel.swift:217`.

---

## Community Theme Submission

We don't keep a private registry — `search.nixos.org` + `brew` are the registry for packages, but themes are curated in-tree (like Omarchy's 22).

1. **Scaffold:** `omanix theme new <my-theme>` (copies `tokyo-night/colors.toml` + `icons.theme`/`vscode.json` to `themes/<my-theme>/`), or `mkdir -p themes/<my-theme>/backgrounds` and copy `themes/tokyo-night/colors.toml`.
2. **Edit palette:** All 25 keys `mode` + `#RRGGBB` (see `themes/tokyo-night/colors.toml:1`). Validate with `nix-instantiate --parse themes/<my-theme>/colors.toml`.
3. **Register enum:** Add `"<my-theme>"` to `modules/core/options.nix:18` `omanix.theme` enum.
4. **Preview:** `omanix theme set <my-theme> && omanix rebuild --preview` (impure, no generation, instant `sketchybar --reload`). Add `backgrounds/*.jpg` and `preview.png` (16:9, 1200x675).
5. **Check:** `nix flake check` (ensures `lib/themed.nix:8` can `fromTOML` your file and Store can render it). No `lib/themed.nix` edit needed — colors auto-propagate.
6. **PR:** Include `themes/<name>/colors.toml`, `icons.theme`, `neovim.lua`, `vscode.json`, `preview.png`, enum entry, and a line in `docs/themes.md` table. CI fails if any `{{ var }}` missing.

Vendor sync: `themes/` at pinned rev, no hand edits to `config/`/`default/`; see `docs/conventions.md:12`.

---

## Troubleshooting

- `error: attribute 'my-theme' missing` — you added `themes/my-theme/` but not to `modules/core/options.nix` enum. Add it.
- Colors not updating — `omanix rebuild` reloads SketchyBar automatically (`activationScripts` does `sketchybar --reload`). Try `sketchybar --reload` manually.
- Ghostty still old — Ghostty reads `~/.config/ghostty/config` on next launch; restart Ghostty.
- Override not working — ensure `omanix.themeOverrides.accent` (not `omanix.theme.colors.accent` if you typo). Both paths work but `themeOverrides` is preferred.
