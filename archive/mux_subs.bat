@echo off
setlocal enabledelayedexpansion

:: Loop through all .mp4 or .mkv files in the current folder
for %%f in (*.mp4, *.mkv) do (
    set "filename=%%~nf"
    set "mp4file=%%f"
    set "srtfile=!filename!.srt"

    :: Check if corresponding .srt file exists
    if exist "!srtfile!" (
        echo Found matching subtitle for !mp4file!: !srtfile!
        ffmpeg -i "!mp4file!" -i "!srtfile!" -map 0 -map 1 -c copy -scodec mov_text -disposition:s:0 default "!filename!_subtitled.mp4"
    ) else (
        echo No matching subtitle found for !mp4file!
    )
)

echo Done.
pause
