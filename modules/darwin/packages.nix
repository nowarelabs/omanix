# modules/darwin/packages.nix — system packages (from config/flake.nix:17-73)
# All packages your Mac needs, declaratively managed
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Core tools
    curl
    wget
    vim
    git
    gh
    tree
    jq
    eza
    htop
    direnv
    nix-direnv
    nixfmt
    nixd
    starship
    devenv

    # Languages
    go
    python313
    poetry
    ruby_3_3
    rubyPackages_3_3.solargraph
    rubyPackages_3_3.ruby-lsp
    rufo
    nodejs_22
    node-gyp
    bun
    php
    phpPackages.composer
    cargo
    rustc
    jdk25
    maven
    gradle

    # Build tools
    pkg-config
    libyaml.dev
    openssl_3_6.dev
    nodePackages.node-gyp
    secp256k1

    # Databases
    postgresql_16
    postgresql16Packages.pgvector
    libpqxx

    # Dev tools
    uv
    buf
    subversion
    git-subrepo
    imagemagick
    ffmpeg
    nmap
    k6
    cloudflared
    google-cloud-sdk
    turso-cli
    mailhog
  ];
}
