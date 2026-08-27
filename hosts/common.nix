# hosts/common.nix — shared between darwin + future linux
# Overlay gate: imports overlays/ impurely for preview (principles.md:15)
# Theme engine is in flake.nix modules list (modules/theme/theme.nix) — not here
{ ... }: {
  imports = (
    if builtins.pathExists ../overlays
    then map (f: ../overlays/${f}) (builtins.attrNames (builtins.readDir ../overlays))
    else []
  );
}
