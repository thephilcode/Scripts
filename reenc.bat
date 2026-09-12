@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: v1.6 - 2026-04-16
:: This version adds better parsing arguments with the addition of the rescale and skip-encode arguments for rescaling and skipping reencoding of videos. 
:: It also removes the pmode=1:pme=1 hevc parameters because they add 1-3% compression at the cost of possibly increasing CPU usage significantly, and were thus deemed not worth the tradeoff.
:: Improve codec tag replacement for filenames with more options for both video and audio codecs
:: Add variable bitrate for audio streams

set "scale_arg="

:: Parsing arguments
for %%A in (%*) do (
    if /i "%%~A"=="--rescale"      set rescale=1 & set "scale_arg=-vf scale=1280:-2 "
    if /i "%%~A"=="-r"             set rescale=1 & set "scale_arg=-vf scale=1280:-2 "
    if /i "%%~A"=="--fast-forward" set fast_forward=1
    if /i "%%~A"=="-f"             set fast_forward=1
    if /i "%%~A"=="--skip-encode"  set skip_encode=1
    if /i "%%~A"=="-s"             set skip_encode=1
)

:: Configuration
set "VIDEO_FILE=%~1"
set "HEVC_PRESET=medium"
set "HEVC_CRF=28"
set "PIX_FORMAT=-pix_fmt yuv420p10le"
set "HEVC_PARAMS=-x265-params bframes=4:rc-lookahead=40:ref=4"
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
set "BASE_EXT=%~x1"
:: Change to set "EXT=%~x1" to maintain the original video format
set "EXT=.mkv"
set "OUTPUT_BASE=%BASE_NAME%"
set "SUB_CODEC="
:: Set subtitle codec based on extension
if "!BASE_EXT!"==".mkv" (
    set "SUB_CODEC=copy"
) else if "!EXT!" == ".mkv" (
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
set "TEMP_NAME=!TEMP_NAME:x264=x265!"
set "TEMP_NAME=!TEMP_NAME:X264=X265!"
set "TEMP_NAME=!TEMP_NAME:H264=H265!"
set "TEMP_NAME=!TEMP_NAME:h264=h265!"
set "TEMP_NAME=!TEMP_NAME:AVC=HEVC!"
set "TEMP_NAME=!TEMP_NAME:avc=hevc!"
set "TEMP_NAME=!TEMP_NAME:AAC=OPUS!"
set "TEMP_NAME=!TEMP_NAME:aac=opus!"
set "TEMP_NAME=!TEMP_NAME:DDP=OPUS!"
set "TEMP_NAME=!TEMP_NAME:ddp=opus!"
set "TEMP_NAME=!TEMP_NAME:FLAC=OPUS!"
set "TEMP_NAME=!TEMP_NAME:flac=opus!"

set "OUTPUT_BASE=!TEMP_NAME!"
if "!OUTPUT_BASE!"=="!BASE_NAME!" (
    set "OUTPUT_BASE=!BASE_NAME!.reencoded"
)
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
    if not "!SUB_EXT!"==".srt" (
        if not "!SUB_EXT!"==".ass" (
            set "SUB_CODEC=subrip"
        )
    ) else (
        set "SUB_CODEC=copy"
    )
    echo %%~ns | findstr ".HI" >nul && set "SUB_DISP=-disposition:s:0 hearing_impaired"
    echo %%~ns | findstr "SDH" >nul && set "SUB_DISP=-disposition:s:0 hearing_impaired"
    echo %%~ns | findstr /i "forced" >nul && set "SUB_DISP=-disposition:s:0 forced"
    if not defined SUB_DISP (
        set "SUB_DISP=-disposition:s:0 default"
    )
    if "%%~ns"=="!BASE_NAME!" (
        echo Matching subtitle found
        set /a matching_sub=1
        goto :build_command
    ) else if "%%~ns"=="!OUTPUT_BASE!" (
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
    set "INPUTS_ABRIDGED=!INPUTS_ABRIDGED! -sub_charenc UTF-8 -i "!MAIN_SUB!""
    set "MAPS_ABRIDGED=!MAPS_ABRIDGED! -map 1"

    set "FFMPEG_CMD=ffmpeg !INPUTS_ABRIDGED! !MAPS_ABRIDGED! !scale_arg!-c:v libx265 -preset %HEVC_PRESET% -crf %HEVC_CRF% %PIX_FORMAT% %HEVC_PARAMS% -c:a libopus -vbr on -c:s !SUB_CODEC! -metadata:s:s:0 language=eng !SUB_DISP! -map_chapters 0 -map_metadata 0 !COMMENTS! -y "!OUTPUT_FILE!""
    
    if !skip_encode! equ 1 (
        set "FFMPEG_CMD=ffmpeg !INPUTS_ABRIDGED! !MAPS_ABRIDGED! -c:v copy -c:a copy -vbr on -c:s !SUB_CODEC! -metadata:s:s:0 language=eng !SUB_DISP! -map_chapters 0 -map_metadata 0 !COMMENTS! -y "!BASE_NAME!.muxed!EXT!""
    )

) else (
    set "FFMPEG_CMD=ffmpeg !INPUTS_ABRIDGED! !MAPS_ABRIDGED! !scale_arg!-c:v libx265 -preset %HEVC_PRESET% -crf %HEVC_CRF% %PIX_FORMAT% %HEVC_PARAMS% -c:a libopus -vbr on -c:s !SUB_CODEC! -map_chapters 0 -map_metadata 0 !COMMENTS! -y "!OUTPUT_FILE!""
)

:: Print the command
echo.
echo ================================================================
if !skip_encode! equ 1 (
    echo Generated FFmpeg command ^(muxing streams to single file^):
) else (
    echo Generated FFmpeg command ^(reencoding to HEVC^):
)
echo ================================================================
echo !FFMPEG_CMD!
echo ================================================================
echo.
if !fast_forward! equ 1 (
    call !FFMPEG_CMD!
) else (
    echo Copy and paste the above command into this CMD window to run it after inspection/tweaks ^(e.g., adjust -crf for quality^).
    echo.
)