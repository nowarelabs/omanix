# modules/darwin/activation.nix — activation scripts for dirs not expressible as launchd
# From config/flake.nix:141-174 — only dirs that truly need sudo mkdir
{ config, ... }: {
  system.activationScripts.preActivation = {
    enable = true;
    text = ''
      # PostgreSQL data dir — cannot be a launchd service (needs initdb first)
      if [ ! -d "/var/lib/postgresql/" ]; then
        echo "Creating PostgreSQL data directory..."
        sudo mkdir -m 750 -p /var/lib/postgresql/
        chown -R ${config.omanix.user}:staff /var/lib/postgresql/
      fi

      # Redis data dir — cannot be a launchd service (needs dir before daemon starts)
      if [ ! -d "/var/lib/redis/" ]; then
        sudo mkdir -p /var/lib/redis/
        chown -R redis:staff /var/lib/redis/
      fi
    '';
  };
}
