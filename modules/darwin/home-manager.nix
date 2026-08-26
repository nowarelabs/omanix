# modules/darwin/home-manager.nix — home-manager integration (darwin-only)
# Installs skills, omanix CLI, and shell config
{ config, ... }: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "backup";

  programs.zsh.enable = true;

  home-manager.users.${config.omanix.user} = {
    home.stateVersion = "25.11";

    # Add ~/.local/bin to PATH for omanix and other local tools
    home.sessionPath = [
      "$HOME/.local/bin"
    ];

    # Install Omanix skills for AI agents + omanix CLI
    home.file = {
      # Skills — link to AI agent directories (source files live in the flake, not here)
      ".claude/skills/omanix/SKILL.md".source = ../../skills/omanix/SKILL.md;
      ".opencode/skills/omanix/SKILL.md".source = ../../skills/omanix/SKILL.md;

      # Omanix CLI — executable script
      ".local/bin/omanix" = {
        source = ../../bin/omanix;
        executable = true;
      };
    };
  };
}
