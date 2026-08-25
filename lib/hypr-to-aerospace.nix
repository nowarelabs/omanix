# lib/hypr-to-aerospace.nix — single file mapping Hyprland bindings → AeroSpace config
# See conventions.md:3 — no scattered translations
# Maps: default/hypr/bindings/*.lua → aerospace.toml
# Maps: default/hypr/looknfeel.lua → gaps, borders
{ lib }:

rec {
  # Hyprland SUPER = AeroSpace cmd (meta)
  mod = "cmd";

  # Workspace bindings: SUPER + 1-9 → cmd + 1-9
  workspaceBindings = builtins.genList (i:
    let n = i + 1; in {
      key = "${mod}-${toString n}";
      action = "workspace";
      args = [ (toString n) ];
    }
  ) 9;

  # Move to workspace: SUPER + SHIFT + 1-9 → cmd + shift + 1-9
  moveToWorkspaceBindings = builtins.genList (i:
    let n = i + 1; in {
      key = "${mod}-shift-${toString n}";
      action = "move-node-to-workspace";
      args = [ (toString n) ];
    }
  ) 9;

  # Focus bindings: SUPER + arrow → cmd + arrow
  focusBindings = [
    { key = "${mod}-left"; action = "focus"; args = ["left"]; }
    { key = "${mod}-right"; action = "focus"; args = ["right"]; }
    { key = "${mod}-up"; action = "focus"; args = ["up"]; }
    { key = "${mod}-down"; action = "focus"; args = ["down"]; }
  ];

  # Move bindings: SUPER + SHIFT + arrow → cmd + shift + arrow
  moveBindings = [
    { key = "${mod}-shift-left"; action = "move"; args = ["left"]; }
    { key = "${mod}-shift-right"; action = "move"; args = ["right"]; }
    { key = "${mod}-shift-up"; action = "move"; args = ["up"]; }
    { key = "${mod}-shift-down"; action = "move"; args = ["down"]; }
  ];

  # Layout bindings
  layoutBindings = [
    { key = "${mod}-t"; action = "layout"; args = ["tiling"]; }
    { key = "${mod}-f"; action = "layout"; args = ["fullscreen"]; }
    { key = "${mod}-w"; action = "close"; args = []; }
  ];

  # Gaps and borders from looknfeel.lua
  # Hyprland gaps_in = 5, gaps_out = 10 → AeroSpace gaps
  # border_size = 2 → AeroSpace border width
  defaultGaps = {
    inner = 8;   # between windows (Hyprland gaps_in = 5, adjusted for macOS)
    outer = 12;  # around screen edges (Hyprland gaps_out = 10, adjusted for notch)
  };

  # All bindings combined
  allBindings = workspaceBindings ++ moveToWorkspaceBindings ++ focusBindings ++ moveBindings ++ layoutBindings;

  # Generate AeroSpace keybinding config string
  generateKeybindings = lib.concatMapStringsSep "\n" (bind:
    "[${mod}]${builtins.replaceStrings [" "] ["+"] (builtins.tail (builtins.split " " bind.key))} = ${bind.action} ${lib.concatStringsSep " " bind.args}"
  ) allBindings;

  # Generate AeroSpace gaps config
  generateGaps = gaps: ''
    [gaps]
    inner = ${toString gaps.inner}
    outer = ${toString gaps.outer}
  '';
}
