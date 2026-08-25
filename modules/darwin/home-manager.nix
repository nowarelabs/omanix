# modules/darwin/home-manager.nix — home-manager integration (darwin-only)
# Installs skills to ~/.config/omanix/skills/ and symlinks to agent dirs
{ config, ... }: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  programs.zsh.enable = true;

  # Install Omanix skills for AI agents
  home.file = {
    ".config/omanix/skills/omanix/SKILL.md".source = ../../skills/omanix/SKILL.md;
    ".config/omanix/skills/omanix/mini-SKILL.md".source = ../../skills/omanix/mini-SKILL.md;

    # Symlinks for Claude and OpenCode visibility
    ".claude/skills/omanix/SKILL.md".source = ../../skills/omanix/SKILL.md;
    ".opencode/skills/omanix/SKILL.md".source = ../../skills/omanix/SKILL.md;
  };
}
