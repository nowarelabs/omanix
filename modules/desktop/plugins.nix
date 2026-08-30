# modules/desktop/plugins.nix — Omanix plugin system (Phase 5)
# Two surfaces, as the brief requires:
# 1. Compile-time (static) plugins: Nix flake derivations whose Swift sources are
#    copied into the GUI build at activation time and compiled into the bar binary.
#    Example: a Spotify widget that ships as a Swift file in a flake input.
# 2. Runtime (dynamic IPC) plugins: long-running processes that talk to the bar
#    via a well-typed Unix socket (JSON-RPC) — isolation so a crashing plugin
#    never takes the bar down. The bar exposes ~/.config/omanix/omanix.sock.
{ config, lib, pkgs, ... }:
let
  user = config.omanix.user;
  cfg = config.omanix.plugins;
in {
  options.omanix.plugins = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Omanix plugin system (both compile-time and runtime IPC).";
      example = false;
    };
    socketPath = lib.mkOption {
      type = lib.types.str;
      default = ".config/omanix/omanix.sock";
      description = "Path to the plugin IPC Unix socket, relative to $HOME. Runtime plugins connect here with JSON-RPC.";
      example = ".config/omanix/omanix.sock";
    };
    # --- Compile-time (static) plugins ---
    # Each entry is a derivation or path whose `src` (or the attr itself if a path)
    # contains Swift source files to be merged into the GUI build. The activation
    # script copies them into $STORE_DIR/gui before swiftc, so they are compiled
    # into the bar binary — zero runtime cost, fully hermetic.
    compileTime = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.src = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a directory containing Swift source files for this plugin. Null means the attr key itself is a flake input path.";
          example = lib.literalExpression "./plugins/spotify";
        };
        options.package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "Optional Nix package providing the plugin's sources (e.g. a Rust crate fetched via flake input).";
        };
      });
      default = {};
      description = "Compile-time plugins: Nix derivations / paths whose Swift sources are compiled into the bar binary at build time.";
      example = {
        spotify.src = ./plugins/spotify;
      };
    };
    # --- Runtime (dynamic IPC) plugins ---
    # Each entry is a command to be run as a launchd user agent that connects to
    # the bar's Unix socket and streams JSON-RPC updates. Isolated: if it crashes,
    # the socket drops and the bar falls back to a default visual state.
    runtime = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.command = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Shell command to run for this runtime plugin (e.g. \"python3 ~/.config/omanix/plugins/weather.py\").";
          example = "python3 ~/.config/omanix/plugins/weather.py";
        };
        options.interval = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "If set, the command is re-executed every N seconds via launchd StartInterval. Null means it is a long-running daemon.";
          example = 60;
        };
      });
      default = {};
      description = "Runtime IPC plugins: processes that connect to the bar's Unix socket and send JSON-RPC updates.";
      example = {
        weather.command = "python3 ~/.config/omanix/plugins/weather.py";
        weather.interval = 300;
      };
    };
  };

  config = lib.mkIf (user != "" && cfg.enable) {
    # Ensure the socket directory exists and is owned by the user.
    system.activationScripts.postActivation.text = lib.mkAfter ''
      mkdir -p "/Users/${user}/.config/omanix" 2>/dev/null || true
      chown ${user}:staff "/Users/${user}/.config/omanix" 2>/dev/null || true
      # Compile-time plugins: copy their Swift sources into the GUI build tree
      # before the GUI activation script runs (it copies $CONFIG_DIR/modules/apps/gui).
      # This is the "Functional Derivations" path from the brief.
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: p:
        let src = if p.src != null then toString p.src else "";
        in lib.optionalString (src != "") ''
          if [ -d "${src}" ]; then
            echo "[plugins] merging compile-time plugin '${name}' from ${src}"
            cp -R -p "${src}/"* "/Users/${user}/.omanix/modules/apps/gui/Modules/Plugins/" 2>/dev/null || true
          fi
        '') cfg.compileTime)}
    '';

    # Runtime plugins as launchd agents (one per entry in `omanix.plugins.runtime`).
    launchd.user.agents = lib.mapAttrs' (name: p: {
      name = "om.omanix.plugin.${name}";
      value = {
        enable = true;
        config = {
          ProgramArguments = [ "/bin/sh" "-c" p.command ];
          RunAtLoad = true;
          KeepAlive = p.interval == null;
          StartInterval = lib.mkIf (p.interval != null) p.interval;
          StandardOutPath = "/Users/${user}/.config/omanix/logs/${name}.log";
          StandardErrorPath = "/Users/${user}/.config/omanix/logs/${name}.log";
          EnvironmentVariables = {
            OMANIX_SOCKET = "/Users/${user}/${cfg.socketPath}";
          };
        };
      };
    }) cfg.runtime;
  };
}
