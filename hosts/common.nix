# hosts/common.nix — shared between darwin + future linux
# Overlay gate: imports overlays/ impurely for preview (principles.md:15).
# Note: flake source copies only git-tracked files, so the gitignored overlays/ only
# enters the eval if it is staged first — `omanix rebuild` does exactly that
# (`git add -f overlays` → eval → `git restore --staged overlays`). Both layouts are
# supported: a flat file (overlays/store-preview.nix) imports directly; a per-app dir
# (overlays/pomodoro/{default.nix,...}) imports its default.nix.
# Theme engine is in flake.nix modules list (modules/theme/theme.nix) — not here
{ ... }: {
  imports = (
    let
      overlayDir = ../overlays;
      entryImport = entry:
        if builtins.pathExists "${overlayDir}/${entry}/default.nix"
        then "${overlayDir}/${entry}/default.nix"
        else "${overlayDir}/${entry}";
    in
    if builtins.pathExists overlayDir
    then map entryImport (builtins.attrNames (builtins.readDir overlayDir))
    else []
  );
}
