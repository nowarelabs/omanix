{ pkgs, ... }:
let
  vidpipe = pkgs.writeShellApplication {
    name = "vidpipe";
    runtimeInputs = with pkgs; [
      ffmpeg
      whisper-cpp
      python3
      coreutils
      gawk
      gnugrep
      gnused
    ];
    text = ''
      export VIDPIPE_CUT=${./cut.py}
    '' + builtins.readFile ./vidpipe.sh;
  };
in
{
  environment.systemPackages = [ vidpipe ];
}
