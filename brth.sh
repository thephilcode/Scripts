#!/usr/bin/env bash
# brth.sh - HEVC re-encode workflow (port of brth.bat)
set -u

logfile="reencode_log.txt"
HEVC_PRESET=medium
HEVC_CRF=28
PIX_FORMAT=(-pix_fmt yuv420p10le)
HEVC_PARAMS=(-x265-params bframes=4:rc-lookahead=40:ref=4)

echo "Starting HEVC re-encoding at $(date)" > "$logfile"
if [ ! -d temp_hevc ]; then
    mkdir temp_hevc
    echo "Created temp_hevc folder" >> "$logfile"
else
    echo "temp_hevc already exists, skipping creation" >> "$logfile"
fi
error_occurred=0
scale_arg=()

for a in "$@"; do
    case "$a" in
        --rescale|-r) rescale=1; scale_arg=(-vf scale=-2:720);;
        --force|-f) force_reencode=1;;
        --skip|-s) skip_existing=1;;
    esac
done

[ -n "${force_reencode+x}" ] && echo "Forced re-encoding of HEVC videos enabled" >> "$logfile"
[ -n "${rescale+x}" ] && echo "Rescaling to 720P enabled" >> "$logfile"
[ -n "${skip_existing+x}" ] && echo "Skipping re-encoding of existing HEVC videos enabled" >> "$logfile"

meta_comment=(-metadata comment="Re-encoded by ScreenPhantom 📺👻")

encode_name() {
    local n="$1"
    n="${n//AV1/HEVC}"
    n="${n//AVC/HEVC}"
    n="${n//x264/x265}"
    n="${n//h264/h265}"
    n="${n//AAC/OPUS}"
    n="${n//aac/opus}"
    n="${n//FLAC/OPUS}"
    n="${n//flac/opus}"
    n="${n//DDP/OPUS}"
    n="${n//ddp/opus}"
    if [ -n "${rescale+x}" ]; then
        n="${n//1080p/720p}"
        n="${n//1080P/720P}"
    fi
    printf '%s.mkv' "$n"
}

packet_end_max() {
    ffprobe -v error -select_streams v,a -show_entries packet=pts_time,duration_time -of csv=p=0 "$1" 2>/dev/null \
        | awk -F, '{if(NF>=2 && $1+0==$1 && $2+0==$2){v=$1+$2; if(v>m) m=v}} END{print m+0}'
}

shopt -s nullglob
for f in *.avi *.mkv *.mp4; do
    orig="${f%.*}"
    ext=".${f##*.}"
    newname="$(encode_name "$orig")"

    # Subtitle stream arguments
    sub_args=()
    sub_stream_idx=0
    sub_args_set=0
    while IFS= read -r codec; do
        [ -z "$codec" ] && continue
        this_subcodec="copy"
        case "$codec" in
            ssa) this_subcodec="ass";;
            mov_text|webvtt) this_subcodec="subrip";;
        esac
        sub_args+=(-c:s:$sub_stream_idx "$this_subcodec")
        sub_stream_idx=$((sub_stream_idx + 1))
        sub_args_set=1
    done < <(ffprobe -v error -select_streams s -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)
    [ $sub_args_set -eq 0 ] && sub_args=(-c:s copy)

    # Dynamic bitrate arguments per audio stream
    audio_args=()
    audio_stream_idx=0
    while IFS= read -r channels; do
        [ -z "$channels" ] && continue
        this_bitrate="96k"
        if [ "$channels" -ge 6 ] 2>/dev/null; then this_bitrate="192k"; fi
        audio_args+=(-c:a:$audio_stream_idx libopus -vbr on -b:a:$audio_stream_idx "$this_bitrate" -ac:a:$audio_stream_idx "$channels")
        meta_comment+=(-metadata:s:a:$audio_stream_idx "comment=Re-encoded by ScreenPhantom 📺👻")
        audio_stream_idx=$((audio_stream_idx + 1))
    done < <(ffprobe -v error -select_streams a -show_entries stream=channels -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)

    # Video stream arguments (preserve attached_pic covers)
    video_args=()
    video_stream_idx=0
    while IFS= read -r attached; do
        [ -z "$attached" ] && continue
        if [ "$attached" -eq 1 ]; then
            video_args+=(-c:v:$video_stream_idx copy)
        else
            video_args+=("${scale_arg[@]}" -c:v:$video_stream_idx libx265 -preset "$HEVC_PRESET" -crf "$HEVC_CRF" "${PIX_FORMAT[@]}" "${HEVC_PARAMS[@]}")
            meta_comment+=(-metadata:s:v:$video_stream_idx "comment=Re-encoded by ScreenPhantom 📺👻")
        fi
        video_stream_idx=$((video_stream_idx + 1))
    done < <(ffprobe -v error -select_streams v -show_streams -of json "$f" 2>/dev/null | jq -r '.streams[].disposition.attached_pic // empty')

    # Skip if already hevc (unless forcing)
    is_hevc=0
    if [ -z "${force_reencode+x}" ]; then
        if ffprobe -c:v hevc -i "$f" >/dev/null 2>&1; then is_hevc=1; fi
    fi

    if [ "$is_hevc" -eq 1 ]; then
        echo "Skipping $orig$ext - already processed" >> "$logfile"
        continue
    fi

    skip_encode=0
    if [ -n "${skip_existing+x}" ]; then
        skip_encode=1
        echo "Skipping re-encoding of $orig$ext due to --skip argument" >> "$logfile"
    elif [ -e "temp_hevc/$newname" ]; then
        if [ -e "temp_hevc/$newname.complete" ]; then
            skip_encode=1
            echo "Skipping $orig$ext - completion marker found" >> "$logfile"
        else
            echo "Checking existing temp_hevc/$newname by decoding it fully" >> "$logfile"
            if ffmpeg -hide_banner -loglevel error -xerror -err_detect explode -i "temp_hevc/$newname" -map 0:v? -map 0:a? -f null - >/dev/null 2>&1; then
                MEDIA_SOURCE="$(pwd)/$orig$ext"
                MEDIA_OUTPUT="$(pwd)/temp_hevc/$newname"
                sourceEnd="$(packet_end_max "$MEDIA_SOURCE")"
                outputEnd="$(packet_end_max "$MEDIA_OUTPUT")"
                if awk -v s="$sourceEnd" -v o="$outputEnd" 'BEGIN{ d=(s>o)?s-o:o-s; exit (d>0.5) }'; then
                    skip_encode=1
                    : > "temp_hevc/$newname.complete"
                    echo "Existing temp_hevc/$newname passed decode and duration validation, skipping re-encoding" >> "$logfile"
                else
                    skip_encode=0
                    rm -f "temp_hevc/$newname.complete"
                    echo "Existing temp_hevc/$newname failed packet-end validation, re-encoding" >> "$logfile"
                fi
            else
                skip_encode=0
                rm -f "temp_hevc/$newname.complete"
                echo "Existing temp_hevc/$newname failed decoding, re-encoding" >> "$logfile"
            fi
        fi
    fi

    # GalaxyTV meta title (probed from video stream title tag)
    meta_title=()
    while IFS= read -r title; do
        [ -z "$title" ] && continue
        if echo "$title" | grep -qi GalaxyTV; then
            meta_title=(-metadata "title=${title//x264/x265}")
        fi
    done < <(ffprobe -v error -select_streams v -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null)

    if [ "$skip_encode" -eq 0 ]; then
        if [ -e "$orig.srt" ]; then
            echo "Encoding $orig$ext and muxing $orig.srt to temp_hevc/$newname" >> "$logfile"
            if ffmpeg -i "$orig$ext" -i "$orig.srt" -map 0 -map 1 -map_chapters 0 -map_metadata 0 \
                "${video_args[@]}" "${audio_args[@]}" "${sub_args[@]}" -c:t copy -c:d copy -movflags +faststart \
                "${meta_title[@]}" "${meta_comment[@]}" "temp_hevc/$newname" -y; then
                : > "temp_hevc/$newname.complete"
                echo "Successfully encoded and muxed $orig$ext and $orig.srt to $newname" >> "$logfile"
            else
                echo "ERROR encoding $orig$ext and muxing $orig.srt" >> "$logfile"
                error_occurred=1
            fi
        else
            echo "Encoding $orig$ext to temp_hevc/$newname" >> "$logfile"
            if ffmpeg -i "$orig$ext" -map 0 -map_chapters 0 -map_metadata 0 \
                "${video_args[@]}" "${audio_args[@]}" "${sub_args[@]}" -c:t copy -c:d copy -movflags +faststart \
                "${meta_title[@]}" "${meta_comment[@]}" "temp_hevc/$newname" -y; then
                : > "temp_hevc/$newname.complete"
                echo "Successfully encoded $orig$ext to $newname" >> "$logfile"
            else
                echo "ERROR encoding $orig$ext" >> "$logfile"
                error_occurred=1
            fi
        fi
    fi
done

if [ "$error_occurred" -eq 0 ]; then
    for f in *.avi *.mkv *.mp4; do
        [ -e "$f" ] || continue
        orig="${f%.*}"
        ext=".${f##*.}"
        is_hevc=0
        if [ -z "${force_reencode+x}" ]; then
            if ffprobe -c:v hevc -i "$f" >/dev/null 2>&1; then is_hevc=1; fi
        fi
        if [ "$is_hevc" -eq 1 ]; then
            echo "Skipping replacement for $orig$ext" >> "$logfile"
        else
            newname="$(encode_name "$orig")"
            if [ -e "temp_hevc/$newname" ]; then
                rm -f "$orig$ext"
                if [ -e "$orig.srt" ]; then rm -f "$orig.srt"; fi
                mv "temp_hevc/$newname" ./
                rm -f "temp_hevc/$newname.complete"
                echo "Replaced $orig$ext with $newname" >> "$logfile"
            fi
        fi
    done
    rmdir temp_hevc 2>/dev/null
    echo "All done! Check $logfile for details."
else
    echo "Errors occurred. Check outputs in temp_hevc and $logfile."
fi
shopt -u nullglob
echo "Ending HEVC re-encoding at $(date)" >> "$logfile"
echo "Done. Log saved to $logfile."
exit "$error_occurred"
