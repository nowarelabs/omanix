# lib/themed.nix — reads themes/<name>/colors.toml, renders templates to /nix/store
# User never touches .tpl files — they set omanix.theme and Nix renders.
# See principles.md:3 and RUNTIME_GATES.md:1
{ lib }:

rec {
  # Read a theme's colors.toml into a Nix attrset
  readTheme = themeName: builtins.fromTOML (builtins.readFile ../../themes/${themeName}/colors.toml);

  # Get the current theme colors from config
  getThemeColors = config: readTheme config.omanix.theme;

  # List all available themes (from themes/ directory)
  availableThemes = builtins.attrNames (builtins.readDir ../../themes);

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
      themedDir = ../../default/themed;
      templateFiles = builtins.readDir themedDir;
    in
    lib.mapAttrs' (name: _:
      lib.nameValuePair "omanix/themed/${name}" {
        source = renderTemplateFile colors name "${themedDir}/${name}";
      }
    ) (lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".tpl" n) templateFiles);
}
