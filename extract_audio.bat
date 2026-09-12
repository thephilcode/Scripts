@echo off
setlocal enabledelayedexpansion

echo Extracting audio from video files using FFmpeg...
echo This script processes .mp4, .avi, and .mkv files in the current directory.
echo Output files will be MP3 format with the same base name.

for %%f in (*.mp4 *.avi *.mkv) do (
    if exist "%%f" (
        echo Processing: %%f
        ffmpeg -i "%%f" -vn -acodec libmp3lame -ab 192k "%%~nf.mp3"
        if !errorlevel! equ 0 (
            echo Successfully extracted audio: %%~nf.mp3
        ) else (
            echo Error processing: %%f
        )
    )
)

echo Done.
pause