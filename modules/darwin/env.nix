# modules/darwin/env.nix — environment variables (from config/flake.nix:227-239)
{ pkgs, config, ... }: {
  environment.variables = {
    POSTGRES_DB_URL =
      "postgresql://${config.omanix.user}:postgres@localhost:5432/postgres?search_path=public&sslmode=disable";
    POSTGRES_DEV_URL =
      "postgresql://${config.omanix.user}:postgres@localhost:5432/postgres?search_path=public&sslmode=disable";
    PKG_CONFIG_PATH =
      "${pkgs.libcxx.dev}:${pkgs.pkg-config}:${pkgs.openssl_3_6.dev}/lib/pkgconfig:${pkgs.libyaml.dev}/lib/pkgconfig:${pkgs.postgresql_16}/lib/pkgconfig:${pkgs.libffi.dev}/lib/pkgconfig:${pkgs.secp256k1}/lib/pkgconfig";
    LIBTOOL = "${pkgs.libtool}";
  };
}
