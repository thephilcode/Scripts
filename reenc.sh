#!/usr/bin/env bash
# reenc.sh - single-file re-encode helper (port of reenc.bat). Prints the ffmpeg command.
set -u

scale_arg=()
for a in "$@"; do
    case "$a" in
        --rescale|-r) rescale=1; scale_arg=(-vf scale=-2:720);;
        --fast-forward|-f) fast_forward=1;;
        --skip-encode|-s) skip_encode=1;;
    esac
done

HEVC_PRESET=medium
HEVC_CRF=28
PIX_FORMAT=(-pix_fmt yuv420p10le)
HEVC_PARAMS=(-x265-params bframes=4:rc-lookahead=40:ref=4)
COMMENTS=(-metadata comment="Re-encoded by ScreenPhantom 📺👻"
          -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻"
          -metadata:s:a:0 comment="Re-encoded by ScreenPhantom 📺👻")

VIDEO_FILE="${1:-}"
if [ -z "$VIDEO_FILE" ]; then
    echo "Error: No video file provided! Drag and drop a video file onto this script, or run manually: reenc.sh \"your_video.mkv\""
    exit 1
fi
if [ ! -e "$VIDEO_FILE" ]; then
    echo "Error: Video file '$VIDEO_FILE' not found! Make sure to run from the parent folder."
    exit 1
fi

BASE_NAME="${VIDEO_FILE%.*}"
BASE_EXT=".${VIDEO_FILE##*.}"
EXT=".mkv"
OUTPUT_BASE="$BASE_NAME"
SUB_CODEC=""

if [ "$BASE_EXT" = ".mkv" ]; then
    SUB_CODEC="copy"
elif [ "$EXT" = ".mkv" ]; then
    SUB_CODEC="subrip"
elif [ "$EXT" = ".mp4" ]; then
    SUB_CODEC="mov_text"
elif [ "$EXT" = ".webm" ]; then
    SUB_CODEC="webvtt"
else
    SUB_CODEC="copy"
fi

TEMP_NAME="$BASE_NAME"
TEMP_NAME="${TEMP_NAME//x264/x265}"
TEMP_NAME="${TEMP_NAME//X264/X265}"
TEMP_NAME="${TEMP_NAME//H264/H265}"
TEMP_NAME="${TEMP_NAME//h264/h265}"
TEMP_NAME="${TEMP_NAME//AVC/HEVC}"
TEMP_NAME="${TEMP_NAME//avc/hevc}"
TEMP_NAME="${TEMP_NAME//AAC/OPUS}"
TEMP_NAME="${TEMP_NAME//aac/opus}"
TEMP_NAME="${TEMP_NAME//DDP/OPUS}"
TEMP_NAME="${TEMP_NAME//ddp/opus}"
TEMP_NAME="${TEMP_NAME//FLAC/OPUS}"
TEMP_NAME="${TEMP_NAME//flac/opus}"

OUTPUT_BASE="$TEMP_NAME"
if [ "$OUTPUT_BASE" = "$BASE_NAME" ]; then
    OUTPUT_BASE="${BASE_NAME}.reencoded"
fi
OUTPUT_FILE="${OUTPUT_BASE}${EXT}"
echo "Output will be: $OUTPUT_FILE"

# Check for a matching subtitle file
MAIN_SUB=""
matching_sub=0
SUB_DISP="-disposition:s:0 default"
for s in *.srt *.ass *.vtt; do
    [ -e "$s" ] || continue
    SUB_EXT=".${s##*.}"
    if [ "$SUB_EXT" = ".ass" ] && [ "$EXT" != ".webm" ]; then
        SUB_CODEC="ssa"
    fi
    if [ "$SUB_EXT" != ".srt" ] && [ "$SUB_EXT" != ".ass" ]; then
        SUB_CODEC="subrip"
    elif [ "$SUB_EXT" = ".srt" ]; then
        SUB_CODEC="copy"
    fi
    echo "$s" | grep -q ".HI" && SUB_DISP="-disposition:s:0 hearing_impaired"
    echo "$s" | grep -q "SDH" && SUB_DISP="-disposition:s:0 hearing_impaired"
    echo "$s" | grep -qi "forced" && SUB_DISP="-disposition:s:0 forced"
    if [ "${s%.*}" = "$BASE_NAME" ]; then
        echo "Matching subtitle found"
        matching_sub=1
        MAIN_SUB="$s"
        break
    elif [ "${s%.*}" = "$OUTPUT_BASE" ]; then
        break
    fi
done

if [ ! -e "$MAIN_SUB" ]; then
    echo "Warning: No subtitle file found in parent folder. Proceeding without default subtitle."
    MAIN_SUB=""
fi

INPUTS=(-i "$VIDEO_FILE")
MAPS=(-map 0)

if [ -n "$MAIN_SUB" ]; then
    INPUTS+=(-sub_charenc UTF-8 -i "$MAIN_SUB")
    MAPS+=(-map 1)

    FFMPEG_CMD=(ffmpeg "${INPUTS[@]}" "${MAPS[@]}" "${scale_arg[@]}" -c:v libx265 -preset "$HEVC_PRESET" -crf "$HEVC_CRF" "${PIX_FORMAT[@]}" "${HEVC_PARAMS[@]}" -c:a libopus -vbr on -c:s "$SUB_CODEC" -metadata:s:s:0 language=eng "$SUB_DISP" -map_chapters 0 -map_metadata 0 "${COMMENTS[@]}" -y "$OUTPUT_FILE")

    if [ -n "${skip_encode+x}" ]; then
        FFMPEG_CMD=(ffmpeg "${INPUTS[@]}" "${MAPS[@]}" -c:v copy -c:a copy -vbr on -c:s "$SUB_CODEC" -metadata:s:s:0 language=eng "$SUB_DISP" -map_chapters 0 -map_metadata 0 "${COMMENTS[@]}" -y "${BASE_NAME}.muxed${EXT}")
    fi
else
    FFMPEG_CMD=(ffmpeg "${INPUTS[@]}" "${MAPS[@]}" "${scale_arg[@]}" -c:v libx265 -preset "$HEVC_PRESET" -crf "$HEVC_CRF" "${PIX_FORMAT[@]}" "${HEVC_PARAMS[@]}" -c:a libopus -vbr on -c:s "$SUB_CODEC" -map_chapters 0 -map_metadata 0 "${COMMENTS[@]}" -y "$OUTPUT_FILE")
fi

echo
echo "================================================================"
if [ -n "${skip_encode+x}" ]; then
    echo "Generated FFmpeg command (muxing streams to single file):"
else
    echo "Generated FFmpeg command (reencoding to HEVC):"
fi
echo "================================================================"
printf '%s\n' "${FFMPEG_CMD[*]}"
echo "================================================================"

if [ -n "${fast_forward+x}" ]; then
    "${FFMPEG_CMD[@]}"
else
    echo "Copy and paste the above command into this terminal to run it after inspection/tweaks (e.g., adjust -crf for quality)."
fi
