# modules/darwin/services.nix — redis + postgresql

{ pkgs, config, ... }: {
  services = {  
    redis = {
      enable = true;
      package = pkgs.redis;
    };

    postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      initdbArgs = [
        "-U ${config.omanix.user}"
        "--pgdata=/var/lib/postgresql/16"
        "--auth=trust"
        "--no-locale"
        "--encoding=UTF8"
      ];
      settings = { listen_addresses = "localhost"; };
      authentication = ''
        local all all              trust
        host  all all 127.0.0.1/32 trust
        host  all all ::1/128      trust
      '';
    };
  };

  launchd.user.agents.postgresql.serviceConfig = {
    StandardErrorPath = "/tmp/postgres.error.log";
    StandardOutPath = "/tmp/postgres.log";
  };

  # Activation script: create dirs + init databases
  system.activationScripts.preActivation.text = ''
    # PostgreSQL data dir
    if [ ! -d "/var/lib/postgresql/" ]; then
      echo "Creating PostgreSQL data directory..."
      sudo mkdir -m 750 -p /var/lib/postgresql/
      chown -R ${config.omanix.user}:staff /var/lib/postgresql/
    fi

    # Redis data dir
    if [ ! -d "/var/lib/redis/" ]; then
      sudo mkdir -p /var/lib/redis/
      chown -R redis:staff /var/lib/redis/
    fi

    # Initialize PostgreSQL database
    if [ ! -d "/var/lib/postgresql/16" ]; then
      echo "Initializing PostgreSQL..."
      sudo -u ${config.omanix.user} initdb --pgdata=/var/lib/postgresql/16 --username=${config.omanix.user} --auth=trust --encoding=UTF8 --locale=en_US.UTF-8 --pwfile=<(echo "postgres")
    fi
  '';
}
