# ice/ — archived code, out of the active build chain

Everything under `ice/` is intentionally **not** part of the active flake: the GUI
build only compiles `modules/apps/gui/**/*.swift`, `flake.nix` imports none of these
files, and no test suite references them. This is where removed-on-hold code lives so
it can be revisited without polluting the live system.

## omabar/ — the old in-app Omabar + plugin host

The in-menu-bar status bar (`Modules/Omabar/`, `Modules/Plugins/`, `Views/OmabarView.swift`,
`Modules/Desktop.swift`, the `SysEvents` monitors, `modules/darwin/omabar.nix`,
`modules/desktop/plugins.nix`, `tests/behavior/OmabarBehaviorTests.swift`) restored verbatim
from commit `8991666` ("feat: add omabar tint"), the last Omabar-era commit before the
spacebar migration deleted it.

Why it went: the native macOS menu bar now serves status items with zero extra
processes; the Omabar plugin host was replaced by declaring bar items as Nix options.
If the plugin idea ever returns, this is its starting point.

## spacebar/nix spacebar.nix — the external bar daemon module

`modules/darwin/spacebar.nix` as it existed before removal (the `spacebar` daemon was a
`nix-darwin services.spacebar` launchd agent drawing a full-width bar outside the native
menu bar, themed from the flake). Removed in favour of the plain native macOS menu bar;
kept here in case the full-width bar idea returns.

## plugins/ — Omabar-era demo plugins

`plugins/spotify-demo/` and `plugins/weather-demo/` moved here (tracked rename) along
with their Omabar-era code.

## Adding / removing

- To restore something: `git mv` (or copy) it back into its original path, delete the
  `ice/` copy, and re-add any `flake.nix` import, option, or test wiring the code needs.
- To archive something new: move it here, then make sure nothing in the build chain
  references it (`flake.nix`, `modules/**/options.nix`, `tests/`).