# modules/services/ollama.nix — Ollama daemon for local AI (Qwen)
# opt-in only: `omanix setup local-ai` pulls the model
# See principles.md:16 and conventions.md:16
{ config, lib, pkgs, ... }:
let
  enabled = config.omanix.services.ollama.enable or false;
in {
  options.omanix.services.ollama = {
    enable = lib.mkEnableOption "Ollama daemon for local AI (opt-in, ~4GB for qwen2.5:7b)";
    model = lib.mkOption {
      type = lib.types.str;
      default = "qwen2.5:7b";
      description = "Ollama model to pull. Use qwen3:8b if RAM >= 16GB.";
      example = "qwen3:8b";
    };
  };

  config = lib.mkIf enabled {
    # Ollama daemon via launchd (darwin) or systemd (linux)
    # Note: ollama is typically installed via brew cask, not nixpkgs
    # This module manages the launchd service
    launchd.agents.ollama = {
      serviceConfig = {
        ProgramArguments = [ "/opt/homebrew/bin/ollama" "serve" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/ollama.stdout.log";
        StandardErrorPath = "/tmp/ollama.stderr.log";
      };
    };
  };
}
