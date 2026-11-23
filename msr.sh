#!/usr/bin/env bash
# msr.sh - mux/subtitle re-encode helper (port of msr.bat). Prints the ffmpeg command.
set -u

HEVC_PRESET=medium
HEVC_CRF=28
PIX_FORMAT=(-pix_fmt yuv420p10le)
HEVC_PARAMS=(-x265-params bframes=4:rc-lookahead=40:ref=4)

VIDEO_FILE="${1:-}"
if [ -z "$VIDEO_FILE" ]; then
    echo "*** ERROR: No video file supplied."
    echo "   Drag-and-drop the video onto this script or run:"
    echo "   $0 \"C:/path/to/your movie.mkv\""
    exit 1
fi
if [ ! -e "$VIDEO_FILE" ]; then
    echo "*** ERROR: File not found: \"$VIDEO_FILE\""
    exit 1
fi

VIDEO_DIR="$(cd "$(dirname "$VIDEO_FILE")" && pwd)"
BASE_NAME="$(basename "$VIDEO_FILE" .${VIDEO_FILE##*.})"

# Output name: codec tag replacements, force .mkv
tmp="$BASE_NAME"
tmp="${tmp//x264/x265}"
tmp="${tmp//H264/H265}"
tmp="${tmp//h264/h265}"
tmp="${tmp//AVC/HEVC}"
tmp="${tmp//AV1/HEVC}"
tmp="${tmp//AAC/OPUS}"
tmp="${tmp//aac/opus}"
tmp="${tmp//DDP/OPUS}"
tmp="${tmp//ddp/opus}"
tmp="${tmp//FLAC/OPUS}"
tmp="${tmp//flac/opus}"
if [ "$tmp" = "$BASE_NAME" ]; then
    OUTBASE="${BASE_NAME}-x265"
else
    OUTBASE="$tmp"
fi
OUTPUT_FILE="${OUTBASE}.mkv"
echo "Output: $OUTPUT_FILE"

# Main subtitle (same name)
MAIN_SUB=""
if [ -e "${VIDEO_DIR}/${BASE_NAME}.srt" ]; then
    MAIN_SUB="${BASE_NAME}.srt"
else
    echo "Warning: No main subtitle \"${BASE_NAME}.srt\""
fi

# Subs folder beside the video
SUBS_DIR="${VIDEO_DIR}/Subs"
if [ ! -d "$SUBS_DIR" ]; then
    echo "*** ERROR: Folder \"$SUBS_DIR\" not found."
    exit 1
fi

INPUTS=(-i "$VIDEO_FILE")
MAPS=(-map 0)
CODECS=(-c:v libx265 -preset "$HEVC_PRESET" -crf "$HEVC_CRF" "${PIX_FORMAT[@]}" "${HEVC_PARAMS[@]}" -c:a libopus -vbr on -c:s copy)
METADATA=()
DISPOSITIONS=()
SUB_COUNT=1

# Add main subtitle (track 0)
if [ -n "$MAIN_SUB" ]; then
    INPUTS+=(-i "$MAIN_SUB")
    MAPS+=(-map "$SUB_COUNT")
    METADATA+=(-metadata:s:s:0 language=eng -metadata:s:s:0 title="English")
    DISPOSITIONS+=(-disposition:s:0 default)
    echo "$BASE_NAME" | grep -qi forced && DISPOSITIONS+=(-disposition:s:0 forced)
    SUB_COUNT=$((SUB_COUNT + 1))
fi

# Collect all .srt from Subs, sorted: English first, then by 3-letter code, then name
mapfile -t SRT_LIST < <(
    cd "$SUBS_DIR" || exit 1
    for s in *.srt; do
        [ -e "$s" ] || continue
        n="${s%.srt}"
        lang="${n: -3}"
        lang="${lang,,}"
        [ "$lang" = "srt" ] && lang="und"
        if [[ "$n" == *.HI ]]; then
            if echo "$n" | grep -qi eng; then lang="eng"
            elif [ ${#n} -ge 6 ]; then lang="${n: -6:3}"
            else lang="und"; fi
            lang="${lang,,}"
        fi
        echo "$n" | grep -qi English && lang="eng"
        printf '%s\t%s\t%s\n' "$lang" "$n" "$s"
    done | sort -t$'\t' -k1,1 -k2,2 | cut -f3
)

# Process each subtitle
for F in "${SRT_LIST[@]}"; do
    [ -z "$F" ] && continue
    FNAME="$(basename "$F" .srt)"
    META_IDX=$((SUB_COUNT - 1))
    DISP=""

    # Language: last 3 chars
    LANG="${FNAME: -3}"
    LANG="${LANG,,}"
    [ "$LANG" = "srt" ] && LANG="und"
    if [[ "$FNAME" == *.HI ]]; then
        DISP="hearing_impaired"
        LANG="und"
    fi
    echo "$FNAME" | grep -qi SDH && DISP="hearing_impaired"
    echo "$FNAME" | grep -qi forced && DISP="forced"

    [ -n "$DISP" ] && DISPOSITIONS+=(-disposition:s:$META_IDX "$DISP")

    # Title: everything before the last 4 chars (.xxx)
    TITLE="${FNAME:0:${#FNAME}-4}"
    if [[ "${FNAME: -3}" == .HI ]]; then
        if echo "$FNAME" | grep -qi eng; then
            LANG=eng
            TITLE="English (SDH)"
        else
            TITLE="SDH"
            LANG="${FNAME: -6:3}"
        fi
    fi
    echo "$FNAME" | grep -qi English && LANG=eng && TITLE="English"
    TITLE="${TITLE% }"  # trim trailing space
    [ -z "$TITLE" ] && TITLE=""
    if [ "$DISP" = "hearing_impaired" ]; then
        echo "$TITLE" | grep -qi SDH || {
            echo "$FNAME" | grep -qi SDH || TITLE="${TITLE} (SDH)"
        }
    fi

    THIS_META=(-metadata:s:s:$META_IDX "language=$LANG")
    [ -n "$TITLE" ] && THIS_META+=(-metadata:s:s:$META_IDX "title=$TITLE")
    METADATA+=("${THIS_META[@]}")

    INPUTS+=(-i "Subs/$(basename "$F")")
    MAPS+=(-map "$SUB_COUNT")
    SUB_COUNT=$((SUB_COUNT + 1))
done

COMMENTS=(-metadata comment="Re-encoded & muxed by ScreenPhantom 📺👻"
          -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻"
          -metadata:s:a:0 comment="Re-encoded by ScreenPhantom 📺👻")

echo
echo "================================================================="
echo "FFmpeg Command (copy and paste into bash):"
echo "================================================================="
printf 'ffmpeg %s %s %s %s %s %s -map_metadata 0 -map_chapters 0 %s "%s"\n' \
    "${INPUTS[*]}" "${CODECS[*]}" "${MAPS[*]}" "${METADATA[*]}" "${DISPOSITIONS[*]}" "${COMMENTS[*]}" "$OUTPUT_FILE"
echo "================================================================="
