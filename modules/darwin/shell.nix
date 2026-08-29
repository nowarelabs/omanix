# modules/darwin/shell.nix — zsh config (from config/home.nix:32-126)
{ config, pkgs, ... }: {
  home-manager.users.${config.omanix.user} = {
    programs.zsh = {
      enable = true;
      initContent = ''
        plugins=(git direnv)

        export PATH=/run/current-system/sw/bin:$HOME/.nix-profile/bin:$HOME/.local/bin:$PATH
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi

        # Omanix aliases
        alias osrebuild='sudo darwin-rebuild switch --flake ~/.omanix'
        alias osconfig='code ~/.omanix'
        alias osclean='omanix clean'
        alias osupdate='omanix update'
        alias osupgrade='omanix upgrade'

        # direnv
        alias allow='direnv allow'

        # Ollama
        alias ollama:start='sudo launchctl load /Library/LaunchDaemons/ollama.plist'
        alias ollama:stop='sudo launchctl unload /Library/LaunchDaemons/ollama.plist'
        alias ollama:open='open -a "Google Chrome" http://localhost:11434'

        # Mailhog
        alias mailhog:start='sudo launchctl load /Library/LaunchDaemons/mailhog.plist'
        alias mailhog:stop='sudo launchctl unload /Library/LaunchDaemons/mailhog.plist'
        alias mailhog:open='open -a "Google Chrome" http://localhost:8025'

        # WiFi — configure via: security find-generic-password -wa "YourSSID"
        # alias wifi:password='security find-generic-password -wa "MotherLAN"'

        # Git
        alias git:lithium='function _gitl() { git clone git@github.com-lithium:lithiumtech/$1.git; }; _gitl'

        # Mac sleep fix
        alias fixsleep='sudo pmset -a hibernatemode 0 && sudo pmset -a standby 0 && sudo pmset -a autopoweroff 0 && echo "Sleep fix applied"'
        alias unfixsleep='sudo pmset -a hibernatemode 3 && sudo pmset -a standby 1 && sudo pmset -a autopoweroff 1 && echo "Sleep settings restored"'
        alias checksleep='pmset -g'

        # Java — use nixpkgs zulu if available, else fall back to Android Studio
        if [[ -d "${pkgs.zulu}/libexec/openjdk" ]]; then
          export JAVA_HOME="${pkgs.zulu}/libexec/openjdk"
        elif [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
          export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        fi

        # AWS
        export AWS_DEFAULT_REGION=eu-west-1

        # NPM
        export PATH="$PATH:$HOME/.npm-packages/bin"

        # Flutter — only if installed
        [[ -d "$HOME/Code/flutter" ]] && export PATH="$HOME/Code/flutter/bin:$PATH"

        # Node modules — only if exists
        [[ -d "$HOME/Code/node_modules/.bin" ]] && export PATH="$HOME/Code/node_modules/.bin:$PATH"

        # Local bin
        export PATH="$HOME/.local/bin:$PATH"

        # Vite+
        . "$HOME/.vite-plus/env" 2>/dev/null || true

        # Prompts
        eval "$(starship init zsh)"
        eval "$(direnv hook zsh)"
      '';
    };

    programs.direnv = {
      enable = true;
      silent = false;
      package = pkgs.direnv;
      nix-direnv = {
        enable = true;
        package = pkgs.nix-direnv;
      };
    };
  };
}
