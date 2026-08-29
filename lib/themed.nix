# lib/themed.nix — reads themes/<name>/colors.toml, renders templates to /nix/store
# User never touches .tpl files — they set omanix.theme and Nix renders.
# See principles.md:3 and conventions.md:4 — centralized theme distribution (Omarchy parity)
{ lib }:

rec {
  # Read a theme's colors.toml into a Nix attrset
  readTheme = themeName: builtins.fromTOML (builtins.readFile ../themes/${themeName}/colors.toml);

  # Get merged theme colors = base palette // user overrides (if any)
  getThemeColors = config:
    let
      base = readTheme config.omanix.theme;
      rawOverrides =
        if config ? omanix && config.omanix ? themeOverrides then config.omanix.themeOverrides
        else {};
      # Filter nulls (mkOption default null means no override)
      overrides = lib.filterAttrs (_: v: v != null) rawOverrides;
    in base // overrides;

  # Per-application colors — global theme+overrides plus per-app delta
  getAppColors = config: app:
    let
      base = getThemeColors config;
      perApp =
        if config ? omanix && config.omanix ? perApp && builtins.hasAttr app config.omanix.perApp
        then (config.omanix.perApp.${app} or {})
        else {};
      filtered = lib.filterAttrs (_: v: v != null) perApp;
    in base // filtered;

  getGhosttyColors = config: getAppColors config "ghostty";
  getSketchyBarColors = config: getAppColors config "sketchybar";
  getAerospaceColors = config: getAppColors config "aerospace";

  # List all available themes (from themes/ directory)
  availableThemes = builtins.attrNames (builtins.readDir ../themes);

  # Render a template string by replacing {{ var }} with theme values
  renderTemplate = colors: templateStr:
    let
      # Strip # from hex colors for templates that need raw hex
      stripHash = color: builtins.substring 1 (builtins.stringLength color - 1) color;
      # Build a attrset with both raw and stripped values
      colorsWithStripped = colors // (
        lib.mapAttrs' (name: value:
          lib.nameValuePair "${name}_strip" (stripHash value)
        ) (lib.filterAttrs (n: v: builtins.isString v && builtins.substring 0 1 v == "#") colors)
      );
      # Replace all {{ var }} with values
      rendered = builtins.replaceStrings
        (map (k: "{{ ${k} }}") (builtins.attrNames colorsWithStripped))
        (map (k: colorsWithStripped.${k}) (builtins.attrNames colorsWithStripped))
        templateStr;
    in rendered;

  # Render a template file to /nix/store
  renderTemplateFile = colors: name: templatePath:
    let
      templateStr = builtins.readFile templatePath;
      rendered = renderTemplate colors templateStr;
    in builtins.toFile name rendered;

  # Get all themed config files for a theme (for xdg.configFile)
  getThemedConfigs = config:
    let
      colors = getThemeColors config;
      themedDir = ../default/themed;
      hasDir = builtins.pathExists themedDir;
      templateFiles = if hasDir then builtins.readDir themedDir else {};
    in
    lib.mapAttrs' (name: _:
      lib.nameValuePair "omanix/themed/${name}" {
        source = renderTemplateFile colors name "${themedDir}/${name}";
      }
    ) (lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".tpl" n) templateFiles);

  # --- Color helpers ---

  # Convert #RRGGBB -> "R,G,B"
  hexToRgb = hex:
    let
      h = lib.removePrefix "#" hex;
      fromHex = s: let
        hexChars = { "0"=0; "1"=1; "2"=2; "3"=3; "4"=4; "5"=5; "6"=6; "7"=7; "8"=8; "9"=9; "a"=10; "b"=11; "c"=12; "d"=13; "e"=14; "f"=15; "A"=10; "B"=11; "C"=12; "D"=13; "E"=14; "F"=15; };
        c1 = builtins.substring 0 1 s;
        c2 = builtins.substring 1 1 s;
      in hexChars.${c1} * 16 + hexChars.${c2};
      r = fromHex (builtins.substring 0 2 h);
      g = fromHex (builtins.substring 2 2 h);
      b = fromHex (builtins.substring 4 2 h);
    in "${toString r},${toString g},${toString b}";

  # Generate Ghostty config text from colors (written to xdg.configFile)
  ghosttyConfig = colors: ''
    # Omanix themed — generated from themes/${colors.background or "unknown"}/colors.toml via lib/themed.nix
    # Do not edit — set omanix.theme instead (see docs/themes.md)
    background = ${lib.removePrefix "#" colors.background}
    foreground = ${lib.removePrefix "#" colors.foreground}
    cursor-color = ${lib.removePrefix "#" colors.accent}
    selection-background = ${lib.removePrefix "#" colors.selection}
    selection-foreground = ${lib.removePrefix "#" colors.foreground}
    palette = 0=${lib.removePrefix "#" colors.background}
    palette = 1=${lib.removePrefix "#" colors.red}
    palette = 2=${lib.removePrefix "#" colors.green}
    palette = 3=${lib.removePrefix "#" colors.yellow}
    palette = 4=${lib.removePrefix "#" colors.blue}
    palette = 5=${lib.removePrefix "#" colors.magenta}
    palette = 6=${lib.removePrefix "#" colors.cyan}
    palette = 7=${lib.removePrefix "#" colors.foreground}
    palette = 8=${lib.removePrefix "#" colors.muted}
    palette = 9=${lib.removePrefix "#" colors.bright_red}
    palette = 10=${lib.removePrefix "#" colors.bright_green}
    palette = 11=${lib.removePrefix "#" colors.bright_yellow}
    palette = 12=${lib.removePrefix "#" colors.bright_blue}
    palette = 13=${lib.removePrefix "#" colors.bright_magenta}
    palette = 14=${lib.removePrefix "#" colors.bright_cyan}
    palette = 15=${lib.removePrefix "#" colors.bright_foreground}
  '';
}
