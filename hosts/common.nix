# hosts/common.nix — shared between darwin + future linux
# Theme, widgets, add/remove logic live here.
# Overlay gate: imports overlays/ impurely for preview (RUNTIME_GATES.md:2)
{ ... }: {
  imports = [
    ../modules/theme/theme.nix
  ] ++ (
    if builtins.pathExists ../overlays
    then map (f: ../overlays/${f}) (builtins.attrNames (builtins.readDir ../overlays))
    else []
  );
}
