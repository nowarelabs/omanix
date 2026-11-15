# vidpipe: raw talking-head video in, upload-ready files out.
# writeShellApplication adds the shebang and `set -euo pipefail`; the
# VIDPIPE_CUT variable (path to cut.py) is exported by default.nix.

usage() {
  cat <<'EOF'
vidpipe: turn a raw talking-head video into an upload-ready one

Usage:
  vidpipe VIDEO [options]
  vidpipe short VIDEO START END     cut a vertical 9:16 clip with captions
                                    (START/END as seconds or hh:mm:ss)

Options:
  -a, --audio FILE      use FILE (e.g. your Mac mic recording) as the audio track
      --clap            auto-sync --audio by matching the first clap in both recordings
      --offset SEC      manual sync: SEC > 0 delays the audio, SEC < 0 pulls it earlier
      --lut FILE        .cube LUT (default: $VIDPIPE_LUT or ~/Videos/luts/filmtone3.cube)
      --lut-strength N  0..1, how strongly the LUT is blended in (default 0.6)
      --no-lut          skip colour grading
      --threshold DB    silence threshold in dB (default -35; raise to -30 if pauses
                        survive, lower to -40 if words get clipped)
      --min-silence S   only cut pauses longer than S seconds (default 0.8)
      --pad S           keep S seconds of air on each side of a cut (default 0.25)
      --no-cut          keep every pause
      --no-captions     skip transcription
      --lang CODE       transcription language (default: en for .en models, else auto)
  -o, --out DIR         output folder (default: ./NAME-vidpipe)
  -h, --help            show this help

Environment:
  VIDPIPE_MODEL   path to a whisper.cpp ggml model (default: best one in ~/.local/share/whisper)
  VIDPIPE_LUT     default LUT file
  VIDPIPE_FONTS   folder with fonts to use for burned-in captions on shorts
EOF
}

die() {
  printf 'vidpipe: %s\n' "$*" >&2
  exit 1
}
step() { printf '\n\033[1m[%s] %s\033[0m\n' "$1" "$2"; }
info() { printf '    %s\n' "$*"; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fps=30
lang_opt=""
venc=()

ff() { ffmpeg -hide_banner -loglevel error -stats -y "$@"; }

duration_of() {
  ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"
}

fmt_time() {
  awk -v t="$1" 'BEGIN { printf "%d:%02d", t / 60, t % 60 }'
}

pick_encoder() {
  local enc
  enc="$(ffmpeg -hide_banner -encoders 2>/dev/null || true)"
  if grep -q 'h264_videotoolbox' <<<"$enc"; then
    venc=(-c:v h264_videotoolbox -b:v 8M -pix_fmt yuv420p -tag:v avc1)
  else
    venc=(-c:v libx264 -crf 20 -preset veryfast -pix_fmt yuv420p)
  fi
}

# Time of the first loud sound (the clap) in a recording.
first_sound() {
  local log
  log="$(ffmpeg -hide_banner -nostats -i "$1" -vn -af "silencedetect=n=-20dB:d=0.3" -f null - 2>&1 || true)"
  grep -m1 'silence_end' <<<"$log" | sed -E 's/.*silence_end: ([0-9.]+).*/\1/' || true
}

find_whisper() {
  local c
  for c in whisper-cli whisper-cpp; do
    if command -v "$c" >/dev/null 2>&1; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

find_model() {
  local m
  if [[ -n "${VIDPIPE_MODEL:-}" && -f "$VIDPIPE_MODEL" ]]; then
    echo "$VIDPIPE_MODEL"
    return 0
  fi
  for m in medium.en medium small.en small base.en; do
    if [[ -f "$HOME/.local/share/whisper/ggml-$m.bin" ]]; then
      echo "$HOME/.local/share/whisper/ggml-$m.bin"
      return 0
    fi
  done
  return 1
}

# transcribe WAV OUTBASE [extra whisper flags]: writes OUTBASE.srt. Returns 1 if skipped or failed.
transcribe() {
  local wav="$1" outbase="$2" bin model lang
  shift 2
  if ! bin="$(find_whisper)"; then
    info "whisper-cpp not found; skipping captions"
    return 1
  fi
  if ! model="$(find_model)"; then
    info "no whisper model found; skipping captions. Download one with:"
    info "  mkdir -p ~/.local/share/whisper && curl -L -o ~/.local/share/whisper/ggml-medium.en.bin \\"
    info "    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin"
    return 1
  fi
  if [[ -n "$lang_opt" ]]; then
    lang="$lang_opt"
  elif [[ "$model" == *.en.bin ]]; then
    lang="en"
  else
    lang="auto"
  fi
  info "transcribing with $(basename "$model") (language: $lang)"
  if ! "$bin" -m "$model" -f "$wav" -l "$lang" -osrt -of "$outbase" "$@" >"$work/whisper.log" 2>&1; then
    tail -n 15 "$work/whisper.log" >&2
    return 1
  fi
}

# make_short VIDEO START END OUTDIR
make_short() {
  local video="$1" start="$2" end="$3" outdir="$4" name clip out style fonts=""
  name="$(basename "${video%.*}")"
  out="$outdir/${name}-short-${start//[:.]/_}.mp4"
  clip="$work/clip.mp4"
  mkdir -p "$outdir"
  pick_encoder

  step "short 1/3" "Cut ${start} to ${end} and crop to 9:16"
  ff -ss "$start" -to "$end" -i "$video" \
    -vf "crop='min(iw,ih*9/16)':'min(ih,iw*16/9)',scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,format=yuv420p" \
    "${venc[@]}" -c:a aac -b:a 160k "$clip"

  step "short 2/3" "Transcribe the clip (short lines for vertical captions)"
  ff -i "$clip" -vn -ar 16000 -ac 1 -c:a pcm_s16le "$work/clip.wav"

  step "short 3/3" "Burn in captions"
  if transcribe "$work/clip.wav" "$work/short" -ml 24 -sow; then
    # Sizes are relative to libass's 288px-tall canvas, so 8 is about 53px on 1920px.
    style="FontName=Arial,FontSize=8,Bold=1,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BorderStyle=1,Outline=1.2,Shadow=0,Alignment=2,MarginV=55"
    if [[ -n "${VIDPIPE_FONTS:-}" ]]; then
      fonts=":fontsdir=${VIDPIPE_FONTS}"
    fi
    (cd "$work" && ff -i "$clip" -vf "subtitles=short.srt${fonts}:force_style='${style}'" "${venc[@]}" -c:a copy "$out")
  else
    info "no captions; saving the clip without them"
    cp "$clip" "$out"
  fi
  printf '\n\033[1mDone.\033[0m  %s\n' "$out"
}

val() { [[ $# -ge 2 ]] || die "$1 needs a value"; }

# ---------------------------------------------------------------- short subcommand
if [[ "${1:-}" == "short" ]]; then
  shift
  [[ $# -eq 3 ]] || die "usage: vidpipe short VIDEO START END"
  [[ -f "$1" ]] || die "video not found: $1"
  short_dir="$(cd "$(dirname "$1")" && pwd)"
  make_short "$short_dir/$(basename "$1")" "$2" "$3" "$short_dir"
  exit 0
fi

# ---------------------------------------------------------------- main pipeline
input=""
audio=""
offset="0"
clap=0
lut="${VIDPIPE_LUT:-$HOME/Videos/luts/filmtone3.cube}"
lut_strength="0.6"
use_lut=1
threshold="-35"
min_silence="0.8"
pad="0.25"
do_cut=1
do_captions=1
outdir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    -a | --audio) val "$@"; audio="$2"; shift 2 ;;
    --clap) clap=1; shift ;;
    --offset) val "$@"; offset="$2"; shift 2 ;;
    --lut) val "$@"; lut="$2"; shift 2 ;;
    --lut-strength) val "$@"; lut_strength="$2"; shift 2 ;;
    --no-lut) use_lut=0; shift ;;
    --threshold) val "$@"; threshold="$2"; shift 2 ;;
    --min-silence) val "$@"; min_silence="$2"; shift 2 ;;
    --pad) val "$@"; pad="$2"; shift 2 ;;
    --no-cut) do_cut=0; shift ;;
    --no-captions) do_captions=0; shift ;;
    --lang) val "$@"; lang_opt="$2"; shift 2 ;;
    -o | --out) val "$@"; outdir="$2"; shift 2 ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *)
      [[ -z "$input" ]] || die "only one input video at a time"
      input="$1"
      shift
      ;;
  esac
done

[[ -n "$input" ]] || { usage; exit 1; }
[[ -f "$input" ]] || die "video not found: $input"

in_abs="$(cd "$(dirname "$input")" && pwd)/$(basename "$input")"
name="$(basename "${input%.*}")"
[[ -n "$outdir" ]] || outdir="$PWD/${name}-vidpipe"
mkdir -p "$outdir"
outdir="$(cd "$outdir" && pwd)"
final="$outdir/$name.mp4"
if [[ "$final" == "$in_abs" ]]; then
  final="$outdir/${name}-final.mp4" # never overwrite the original
fi

# ---- 1. Probe
step "1/6" "Inspect the input"
duration="$(duration_of "$in_abs")"
transfer="$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of csv=p=0 "$in_abs" 2>/dev/null || true)"
astreams="$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$in_abs" 2>/dev/null || true)"
info "length $(fmt_time "$duration")"
case "$transfer" in
  smpte2084* | arib-std-b67*)
    info "WARNING: this looks like HDR footage. Colours will look washed out."
    info "         Turn HDR video off in your camera settings and re-record."
    ;;
  *) ;;
esac
if [[ -z "$audio" && -z "$astreams" ]]; then
  die "the video has no audio track; pass one with --audio"
fi

# ---- 2. Sync external audio
step "2/6" "Sync external audio"
src="$in_abs"
if [[ -n "$audio" ]]; then
  [[ -f "$audio" ]] || die "audio file not found: $audio"
  if ((clap)); then
    vclap="$(first_sound "$in_abs")"
    aclap="$(first_sound "$audio")"
    [[ -n "$vclap" && -n "$aclap" ]] || die "could not find a clap in both recordings; use --offset SEC instead"
    offset="$(awk -v v="$vclap" -v a="$aclap" 'BEGIN { printf "%.3f", v - a }')"
    info "clap at ${vclap}s in the video, ${aclap}s in the mic audio -> offset ${offset}s"
  fi
  if awk -v o="$offset" 'BEGIN { exit !(o >= 0) }'; then
    shift_args=(-itsoffset "$offset")
  else
    shift_args=(-ss "${offset#-}")
  fi
  src="$work/synced.mkv"
  ff -i "$in_abs" "${shift_args[@]}" -i "$audio" -map 0:v:0 -map 1:a:0 -c:v copy -c:a pcm_s16le -shortest "$src"
else
  info "skipped (no --audio given)"
fi

# ---- 3. Find pauses
step "3/6" "Find pauses to cut"
dur_src="$(duration_of "$src")"
[[ "$dur_src" =~ ^[0-9.]+$ ]] || dur_src="$duration"
if ((do_cut)); then
  ffmpeg -hide_banner -nostats -i "$src" -vn \
    -af "highpass=f=80,silencedetect=n=${threshold}dB:d=${min_silence}" \
    -f null - 2>"$work/silence.log"
  python3 "$VIDPIPE_CUT" "$work/silence.log" --duration "$dur_src" --pad "$pad" --out "$work/keep.expr"
else
  printf '1' >"$work/keep.expr"
  info "skipped (--no-cut)"
fi
keep_expr="$(<"$work/keep.expr")"

# ---- 4. Render: cut + clean audio + grade, in a single encode
step "4/6" "Render: cut pauses, clean audio, grade colour"
vchain="[0:v]fps=${fps},select='${keep_expr}',setpts=N/(${fps}*TB),scale=-2:'min(1080,ih)':flags=lanczos,format=yuv420p"
if ((use_lut)) && [[ -f "$lut" ]]; then
  cp "$lut" "$work/lut.cube"
  if awk -v s="$lut_strength" 'BEGIN { exit !(s >= 0.999) }'; then
    graph="${vchain},lut3d=file=lut.cube,format=yuv420p[v]"
  else
    # blend's all_opacity weights its FIRST input, so the LUT version goes first: [l][o]
    graph="${vchain}[v0];[v0]split[o][g];[g]lut3d=file=lut.cube,format=yuv420p[l];[l][o]blend=all_mode=normal:all_opacity=${lut_strength},format=yuv420p[v]"
  fi
  info "LUT $(basename "$lut") at strength ${lut_strength}"
else
  if ((use_lut)); then
    info "LUT not found at $lut; rendering without colour grading"
  else
    info "colour grading skipped (--no-lut)"
  fi
  graph="${vchain}[v]"
fi
achain="[0:a]aselect='${keep_expr}',asetpts=N/SR/TB,highpass=f=80,afftdn=nr=12:nf=-30,acompressor=threshold=-18dB:ratio=3:attack=20:release=250,loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000[a]"
graph="${graph};${achain}"

pick_encoder
(cd "$work" && ff -i "$src" -filter_complex "$graph" -map "[v]" -map "[a]" \
  "${venc[@]}" -c:a aac -b:a 160k -movflags +faststart "$final")
fdur="$(duration_of "$final")"
info "wrote $(basename "$final") ($(fmt_time "$fdur"))"

# ---- 5. Captions
step "5/6" "Transcribe and write captions"
if ((do_captions)); then
  ff -i "$final" -vn -ar 16000 -ac 1 -c:a pcm_s16le "$work/final16k.wav"
  if transcribe "$work/final16k.wav" "$outdir/$name" -otxt; then
    info "wrote $name.srt (upload to YouTube Studio) and $name.txt (plain transcript)"
  fi
else
  info "skipped (--no-captions)"
fi

# ---- 6. Thumbnails
step "6/6" "Grab thumbnail candidates"
for pct in 15 40 65; do
  t="$(awk -v d="$fdur" -v p="$pct" 'BEGIN { printf "%.2f", d * p / 100 }')"
  ff -ss "$t" -i "$final" -frames:v 1 -q:v 2 "$outdir/${name}-thumb-${pct}.jpg"
done
info "wrote ${name}-thumb-15/40/65.jpg"

printf '\n\033[1mDone.\033[0m  %s -> %s   (%s)\n\n' "$(fmt_time "$duration")" "$(fmt_time "$fdur")" "$outdir"
ls -lh "$outdir"
printf '\nNext: vidpipe short "%s" START END   (vertical clip with captions)\n' "$final"
