# modules/darwin/packages.nix — system packages (from config/flake.nix:17-73)
# All packages your Mac needs, declaratively managed
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Core tools
    curl
    devenv
    direnv
    eza
    gh
    git
    htop
    jq
    nix-direnv
    nixd
    nixfmt
    starship
    tree
    vim
    wget

    # Languages
    bun
    cargo
    go
    gradle
    jdk25
    maven
    nodejs_22
    php
    phpPackages.composer
    poetry
    python313
    ruby_3_3
    rubyPackages_3_3.ruby-lsp
    rubyPackages_3_3.solargraph
    rufo
    rustc

    # Build tools
    libyaml.dev
    nodePackages.node-gyp
    openssl_3_6.dev
    pkg-config
    secp256k1

    # Databases
    libpqxx
    postgresql_16
    postgresql16Packages.pgvector

    # Dev tools
    buf
    cloudflared
    ffmpeg
    git-subrepo
    google-cloud-sdk
    imagemagick
    k6
    mailhog
    nmap
    subversion
    turso-cli
    uv
  ];
}
