# Omanix SKILL.md — machine-readable schema for AI agents (frontier Claude/OpenCode)
# Auto-installed to ~/.config/omanix/skills/omanix/SKILL.md
# Symlinked to ~/.claude/skills/omanix/SKILL.md and ~/.opencode/skills/omanix/SKILL.md
# See conventions.md:15 and principles.md:15

## Contract

You are building for Omanix, a declarative desktop for macOS (and future Linux).
Everything is a Nix derivation. You write Nix modules, not bash scripts.

### Core Helpers

- `lib/mkWidget { name, sketchybarConfig, launchdConfig, swiftSrc, dependencies }` → module
- `lib/mkApp { name, bundleId, src, plistConfig }` → /Applications/*.app derivation
- `lib/mkSystem { system, modules }` → darwinSystem or nixosSystem (branches on isDarwin)

### Theme Tokens

Access theme colors via `${config.lib.omanixTheme.colors.accent}` in Nix expressions.
Available colors: accent, background, foreground, red, yellow, orange, green, cyan, blue, magenta, etc.
Never hardcode `#7aa2f7` — always use `${config.lib.omanixTheme.colors.accent}`.

### Widget Pattern

```nix
{ config, lib, pkgs, ... }:
let
  enabled = config.omanix.widgets.pomodoro.enable;
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
in {
  config = lib.mkIf enabled {
    xdg.configFile."sketchybar/plugins/pomodoro.sh" = {
      text = ''
        #!/bin/bash
        sketchybar --set pomodoro icon="󰔟" label="25:00"
      '';
      executable = true;
    };
    launchd.user.agents.omanix-pomodoro = {
      serviceConfig = {
        ProgramArguments = [ "${pkgs.bash}/bin/bash" "-c" "echo tick" ];
        StartInterval = 60;
      };
    };
  };
}
```

### Two-Phase Build (Preview → Commit)

1. **Draft (no build):** Write `overlays/pomodoro/{default.nix}` (impure, git-ignored)
2. **Preview (impure, instant):** `omanix rebuild --preview` — builds overlay, hot-reloads sketchybar
3. **Commit (pure):** `omanix add pomodoro --from-overlay overlays/pomodoro` → moves to `configuration.nix`
4. **Undo:** `omanix rebuild --rollback` or `rm -rf overlays/pomodoro && omanix rebuild --preview`

### Lint (required before any rebuild)

```bash
statix check .           # no unused bindings
nix fmt                  # nixfmt, two-space
nix-instantiate --parse  # valid Nix syntax
```

### What NOT to Do

- Never write to `/nix/store`
- Never use `echo` or `sed` to edit `configuration.nix` (use `omanix add` helpers)
- Never use `xdg.configFile.*.text` for things that have `omanix.*` options
- Never use `home.activation` bash that `git clone`s or `mkdir -p ~/.config`
- Never hardcode colors — use theme tokens
