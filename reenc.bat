@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: v1.3 - 2025-12-07
:: This version can also simply mux a video with it's subtitle file without reencoding it if its codec is already hevc.

:: Configuration
set "VIDEO_FILE=%~1"
set "HEVC_PRESET=medium"
set "HEVC_CRF=28"
set "COMMENTS=-metadata comment="Re-encoded by ScreenPhantom 📺👻""
set "COMMENTS=!COMMENTS! -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻""

:: Check if video file is provided and exists
if "%VIDEO_FILE%"=="" (
    echo Error: No video file provided! Drag and drop a video file onto this script, or run manually: reenc.bat "your_video.mkv"
    pause
    exit /b 1
)
if not exist "%VIDEO_FILE%" (
    echo Error: Video file '%VIDEO_FILE%' not found! Make sure to run from the parent folder.
    pause
    exit /b 1
)

:: Derive output filename with x264 -> x265 replacement (case-insensitive, no full lowering)
set "BASE_NAME=%~n1"
:: Change to set "EXT=%~x1" to maintain the original video format
set "EXT=.mkv"
set "OUTPUT_BASE=%BASE_NAME%"
set "SUB_CODEC="
:: Set subtitle codec based on extension
if "!EXT!" == ".mkv" (
    set "SUB_CODEC=subrip"
) else if "!EXT!" == ".mp4" (
    set "SUB_CODEC=mov_text"
) else if "!EXT!"==".webm" (
    set "SUB_CODEC=webvtt"
) else (
    set "SUB_CODEC=copy"
)

:: Check and replace first "x264" or "X264"
set "TEMP_NAME=%BASE_NAME%"
:replace_loop
if not "!TEMP_NAME!"=="" (
    set "TEMP_NAME=!TEMP_NAME:x264=x265!"
    if "!TEMP_NAME!"=="%BASE_NAME%" (
        set "TEMP_NAME=!TEMP_NAME:X264=X265!"
        set "TEMP_NAME=!TEMP_NAME:AVC=HEVC!"
    )
    set "OUTPUT_BASE=!TEMP_NAME!"
    goto :done_replace
)
:done_replace
set "OUTPUT_FILE=!OUTPUT_BASE!!EXT!"
echo Output will be: !OUTPUT_FILE!

:: Check if subtitle file exists
for %%s in (*.srt *.ass *.vtt) do (
    set "SUB_EXT=%%~xs"
    set "MAIN_SUB=%%s"
    if "!SUB_EXT!"==".ass" (
        if not "!EXT!"==".webm" (
            set "SUB_CODEC=ssa"
        )
    )
    if "%%~ns"=="!BASE_NAME!" (
        goto :build_command
    ) else if "%%~ns"=="!OUTPUT_BASE!" (
        echo Matching subtitle found
        set /a matching_sub=1
        goto :build_command
    )
)
if not exist "!MAIN_SUB!" (
    echo Warning: No subtitle file found in parent folder. Proceeding without default subtitle.
    set "MAIN_SUB="
)

:build_command
set "INPUTS_ABRIDGED=-i "%VIDEO_FILE%""
set "MAPS_ABRIDGED=-map 0"

:: Build ffpeg command
if exist "!MAIN_SUB!" (
    set "INPUTS_ABRIDGED=!INPUTS_ABRIDGED! -i "!MAIN_SUB!""
    set "MAPS_ABRIDGED=!MAPS_ABRIDGED! -map 1"

    set "FFMPEG_CMD=ffmpeg !INPUTS_ABRIDGED! !MAPS_ABRIDGED! -c:v libx265 -preset %HEVC_PRESET% -crf %HEVC_CRF% -c:a copy -c:s !SUB_CODEC! -metadata:s:s:0 language=eng -disposition:s:0 default -map_chapters 0 -map_metadata 0 !COMMENTS! -y "!OUTPUT_FILE!""

    if "%OUTPUT_FILE%"=="%VIDEO_FILE%" if defined matching_sub (
        set "FFMPEG_CMD=ffmpeg !INPUTS_ABRIDGED! !MAPS_ABRIDGED! -c:v copy -c:a copy -c:s !SUB_CODEC! -metadata:s:s:0 language=eng -disposition:s:0 default -map_chapters 0 -map_metadata 0 !COMMENTS! -y "!OUTPUT_FILE!""
    )

) else (
    set "FFMPEG_CMD=ffmpeg !INPUTS_ABRIDGED! !MAPS_ABRIDGED! -c:v libx265 -preset %HEVC_PRESET% -crf %HEVC_CRF% -c:a copy -map_chapters 0 -map_metadata 0 !COMMENTS! -y "!OUTPUT_FILE!""

)

:: Print the command
echo.
echo ================================================================
echo Generated FFmpeg command ^(reencoding to HEVC^):
echo ================================================================
echo !FFMPEG_CMD!
echo ================================================================
echo.
echo Copy and paste the above command into this CMD window to run it after inspection/tweaks ^(e.g., adjust -crf for quality^).
echo.
