# modules/darwin/desktop.nix — AeroSpace tiling + SketchyBar (mac-only)
# Phase 03 stub — will be fleshed out with real AeroSpace/SketchyBar config
# See conventions.md:3 for Hyprland → AeroSpace mapping
{ config, lib, pkgs, ... }:
let
  themed = import ../../lib/themed.nix { inherit lib; };
  colors = themed.getThemeColors config;
in {
  # AeroSpace tiling window manager
  services.aerospace = {
    enable = true;
    # TODO: Phase 03 — AeroSpace config from hypr-to-aerospace.nix mapping
    # settings = { ... };
  };

  # SketchyBar status bar
  services.sketchybar = {
    enable = true;
    # TODO: Phase 03 — SketchyBar config from themed.nix rendering
    # config = { ... };
  };

  # Theme-colored config files (rendered at build time)
  # xdg.configFile."aerospace/aerospace.toml".source = themed.renderTemplateFile colors "aerospace.toml" ../../default/themed/aerospace.toml.tpl;
  # xdg.configFile."sketchybar/sketchybarrc".source = ...;
}
