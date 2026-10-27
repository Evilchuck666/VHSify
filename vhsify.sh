#!/usr/bin/env bash
# VHSify — give any video a worn-out VHS look (video + audio) with FFmpeg and SoX.
# Works on GNU/Linux and macOS (including the stock bash 3.2).

set -euo pipefail

VERSION="1.1.0"
PROG="${0##*/}"


# === Global Constants === #

# 🔧 General Settings
SAMPLE_RATE=48000
BIT_DEPTH=32
CHANNELS=2
LOW_PASS_FREQ=4000
IN_VOL=1.0
OUT_VOL=0.077
DB=-22.75
DB_VOLUME=$(awk -v db="$DB" 'BEGIN { printf "%.6f", 10 ^ (db / 20) }')

# 🎨 VHS Filter (ffmpeg)
FFMPEG_FILTER="[0:v:0] format=yuv420p, split=3 [a][b][c];
    [a] extractplanes=y [y];
    [b] extractplanes=u [u];
    [c] extractplanes=v [v];
    [y] scale=768:1080, scale=1920:1080 [luma_scaled];
    [u] scale=120:540, scale=960:540 [u_scaled];
    [v] scale=120:540, scale=960:540 [v_scaled];
    [luma_scaled][u_scaled][v_scaled] mergeplanes=0x001020:yuv420p [merged];
    [merged] eq=saturation=0.75, noise=alls=5:allf=t, geq='lum(X+5.5*(random(floor(Y/96))-0.5),Y)':cb='cb(X,Y)':cr='cr(X,Y)' [outv]"

# 🎞️ Codecs & formats
V_CODEC="utvideo"
A_CODEC="pcm_f32le"
PIX_FMT="yuv420p"
VID_COLORSPACE="bt709"


# === Global Variables === #
OUTPUT_DIR=""
SUFFIX="_vhs"
WORK_DIR=""


# === Functions === #
usage() {
    cat <<EOF
VHSify $VERSION — apply a VHS look to video and audio using FFmpeg and SoX.

Usage:
  $PROG [options] VIDEO [VIDEO...]
  $PROG [options] --list LIST_FILE

Options:
  -l, --list FILE        Process every video in FILE: a JSON array of paths
                         or a plain text file with one path per line.
  -o, --output-dir DIR   Write results to DIR (default: next to each input).
  -s, --suffix TEXT      Suffix added to the output name (default: "$SUFFIX").
  -h, --help             Show this help and exit.
  -V, --version          Show the version and exit.

With no VIDEO and no --list, you are asked for a path (drag & drop works).
Output: <basename>$SUFFIX.avi (UTVideo + PCM float, lossless).
EOF
}

if [[ -t 1 ]]; then C_SAY=$'\033[1;35m' C_ERR=$'\033[1;31m' C_OFF=$'\033[0m'; else C_SAY="" C_ERR="" C_OFF=""; fi

say()  { printf '%s####%s %s\n' "$C_SAY" "$C_OFF" "$*"; }
die()  { printf '%sError:%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

cleanup() {
    if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

check_dependencies() {
    local tool
    for tool in ffmpeg ffprobe sox; do
        command -v "$tool" >/dev/null 2>&1 || die "'$tool' not found in PATH. See the README for install instructions."
    done
}

# Paths dropped on a terminal may come quoted ('…' / "…") or backslash-escaped (macOS).
clean_path() {
    local p="$1"
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    if [[ "$p" == \"*\" || "$p" == \'*\' ]]; then
        p="${p:1:${#p}-2}"
    elif [[ "$p" == *\\* && ! -e "$p" ]]; then
        p=$(printf '%s' "$p" | sed 's/\\\(.\)/\1/g')
    fi
    printf '%s' "$p"
}

read_list() {
    local list="$1" first
    [[ -f "$list" ]] || die "The list file '$list' does not exist."

    first=$(tr -d ' \t\r\n' < "$list" | cut -c1)
    if [[ "$first" == "[" ]]; then
        if command -v jq >/dev/null 2>&1; then
            jq -r '.[]' "$list"
        elif command -v python3 >/dev/null 2>&1; then
            python3 -c 'import json, sys; print("\n".join(json.load(open(sys.argv[1], encoding="utf-8"))))' "$list"
        else
            die "Reading a JSON list needs 'jq' or 'python3'. Use a plain text list instead."
        fi
    else
        grep -Ev '^[[:space:]]*(#|$)' "$list" | tr -d '\r'
    fi
}

has_audio() {
    [[ -n "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1")" ]]
}

get_duration() {
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1"
}

step0_vhs_fx() {
    local input="$1" with_audio="$2"
    say "Running Step 0: Applying VHS Effect to video"

    local audio_out=()
    if [[ "$with_audio" == yes ]]; then
        audio_out=(-map 0:a:0 -c:a "$A_CODEC" -ar "$SAMPLE_RATE" -ac "$CHANNELS" "$WORK_DIR/audio.wav")
    fi

    ffmpeg -nostdin -hide_banner -loglevel warning -stats -y \
        -i "$input" \
        -filter_complex "$FFMPEG_FILTER" \
        -map '[outv]' \
        -c:v "$V_CODEC" \
        -pix_fmt "$PIX_FMT" \
        -colorspace "$VID_COLORSPACE" \
        -color_primaries "$VID_COLORSPACE" \
        -color_trc "$VID_COLORSPACE" \
        "$WORK_DIR/vhs.avi" \
        "${audio_out[@]+"${audio_out[@]}"}"
}

step1_audio_fx() {
    local input="$1" with_audio="$2" duration
    say "Running Step 1: Applying VHS Effect to audio"

    duration=$(get_duration "$input")
    if [[ -z "$duration" || "$duration" == "N/A" ]]; then
        die "Cannot get the duration from input file."
    fi

    # 1. Brown noise
    sox -n -r "$SAMPLE_RATE" -b "$BIT_DEPTH" -e floating-point -c "$CHANNELS" \
        "$WORK_DIR/noise.wav" synth "$duration" brownnoise vol "$DB_VOLUME"

    if [[ "$with_audio" == yes ]]; then
        # 2. Mix
        sox -m -v "$IN_VOL" "$WORK_DIR/audio.wav" -v "$OUT_VOL" "$WORK_DIR/noise.wav" "$WORK_DIR/mix.wav"
    else
        # No audio track: the tape hiss is all there is.
        sox -v "$OUT_VOL" "$WORK_DIR/noise.wav" "$WORK_DIR/mix.wav"
    fi

    # 3. Low-pass filter
    sox "$WORK_DIR/mix.wav" "$WORK_DIR/vhs.wav" lowpass "$LOW_PASS_FREQ"
}

step2_map_inputs() {
    local output="$1"
    say "Running Step 2: Mixing video and audio tracks into a single file"

    ffmpeg -nostdin -hide_banner -loglevel error -y \
        -i "$WORK_DIR/vhs.avi" \
        -i "$WORK_DIR/vhs.wav" \
        -map 0:v -map 1:a \
        -c copy \
        "$output"
}

step3_clean() {
    rm -f "$WORK_DIR"/noise.wav "$WORK_DIR"/mix.wav "$WORK_DIR"/vhs.avi "$WORK_DIR"/vhs.wav "$WORK_DIR"/audio.wav
}

process_video() {
    local input="$1" dir base output with_audio=no

    [[ -f "$input" ]] || die "File '$input' does not exist."

    dir="${OUTPUT_DIR:-$(dirname "$input")}"
    base="$(basename "$input")"
    base="${base%.*}"
    output="$dir/$base$SUFFIX.avi"

    has_audio "$input" && with_audio=yes

    say "Processing: $input"
    step0_vhs_fx "$input" "$with_audio"
    step1_audio_fx "$input" "$with_audio"
    step2_map_inputs "$output"
    step3_clean
    say "Done: $output"
}

main() {
    local list="" videos=() line

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list)       [[ $# -ge 2 ]] || die "$1 needs a file."; list="$2"; shift 2 ;;
            -o|--output-dir) [[ $# -ge 2 ]] || die "$1 needs a directory."; OUTPUT_DIR="$2"; shift 2 ;;
            -s|--suffix)     [[ $# -ge 2 ]] || die "$1 needs a value."; SUFFIX="$2"; shift 2 ;;
            -h|--help)       usage; exit 0 ;;
            -V|--version)    echo "VHSify $VERSION"; exit 0 ;;
            --)              shift; videos+=("$@"); break ;;
            -*)              die "Unknown option '$1'. Try '$PROG --help'." ;;
            *)               videos+=("$1"); shift ;;
        esac
    done

    check_dependencies

    if [[ -n "$list" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && videos+=("$line")
        done < <(read_list "$list")
        [[ ${#videos[@]} -gt 0 ]] || die "The list '$list' has no videos."
    fi

    if [[ ${#videos[@]} -eq 0 ]]; then
        echo "Drag the video here or type the full path"
        read -r -p "Video path: " line || true
        line=$(clean_path "$line")
        [[ -n "$line" ]] || die "No video given."
        videos=("$line")
    fi

    if [[ -n "$OUTPUT_DIR" ]]; then
        mkdir -p "$OUTPUT_DIR" || die "Cannot create the output folder '$OUTPUT_DIR'."
    fi

    WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/vhsify.XXXXXX")
    trap cleanup EXIT
    trap 'exit 130' INT TERM

    for line in "${videos[@]}"; do
        process_video "$line"
    done
}


# === Main === #
main "$@"
