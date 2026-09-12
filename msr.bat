@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: v2.1 - 2026-02-14
:: This update includes a minor improvement in the handling of hearing_impaired subtitles across languages.
:: Added yuv420p10le pixel format option and x265-params for slightly faster reencoding and better compression.
:: Improve codec tag replacement for filenames with more options for both video and audio codecs
:: Add variable bitrate for audio streams

set "SUBS_DIR=Subs"
set "HEVC_PRESET=medium"
set "HEVC_CRF=28"
set "PIX_FORMAT=-pix_fmt yuv420p10le"
set "HEVC_PARAMS=-x265-params bframes=4:rc-lookahead=40:ref=4"

rem ---- Video file -------------------------------------------------
set "VIDEO_FILE=%~1"
if "%VIDEO_FILE%"=="" (
    echo *** ERROR: No video file supplied.
    echo    Drag-and-drop the video onto this .bat or run:
    echo    %~nx0 "C:\path\to\your movie.mkv"
    pause & exit /b 1
)
if not exist "%VIDEO_FILE%" (
    echo *** ERROR: File not found: "%VIDEO_FILE%"
    pause & exit /b 1
)

rem ---- Output name: x264 → x265, force .mkv -----------------------
set "BASE=%~n1"
set "EXT=.mkv"
set "OUTBASE=!BASE!"
set "tmp=!BASE!"
:replace
if defined tmp (
    set "tmp=!tmp:x264=x265!"
    set "tmp=!tmp:H264=H265!"
    set "tmp=!tmp:h264=h265!"
    set "tmp=!tmp:AVC=HEVC!"
    set "tmp=!tmp:AV1=HEVC!"
    set "tmp=!tmp:AAC=OPUS!"
    set "tmp=!tmp:aac=opus!"
    set "tmp=!tmp:DDP=OPUS!"
    set "tmp=!tmp:ddp=opus!"
    set "tmp=!tmp:FLAC=OPUS!"
    set "tmp=!tmp:flac=opus!"
    if "!tmp!"=="!BASE!" (
        set "OUTBASE=!BASE!-x265"
        goto :done_replace
    )
    set "OUTBASE=!tmp!"
    goto :done_replace
)
:done_replace
set "OUTPUT_FILE=!OUTBASE!!EXT!"
echo Output: !OUTPUT_FILE!

rem ---- Main subtitle (same name) ----------------------------------
set "MAIN_SUB=!BASE!.srt"
if exist "!MAIN_SUB!" (
    set "MAIN_SUB=!MAIN_SUB!"
) else (
    set "MAIN_SUB="
    echo Warning: No main subtitle "!BASE!.srt"
)

rem ---- Subs folder ------------------------------------------------
if not exist "!SUBS_DIR!\" (
    echo *** ERROR: Folder "!SUBS_DIR!" not found.
    pause & exit /b 1
)

rem ---- FFmpeg building blocks --------------------------------------
set "INPUTS=-i "!VIDEO_FILE!""
set "MAPS=-map 0"
set "CODECS=-c:v libx265 -preset %HEVC_PRESET% -crf %HEVC_CRF% %PIX_FORMAT% %HEVC_PARAMS% -c:a libopus -vbr on -c:s copy"
set "METADATA="
set "DISPOSITIONS="
set /a SUB_COUNT=1

rem ---- Add main subtitle (track 0) --------------------------------
if defined MAIN_SUB (
    set "INPUTS=!INPUTS! -i "!MAIN_SUB!""
    set "MAPS=!MAPS! -map !SUB_COUNT!"
    set "METADATA=!METADATA! -metadata:s:s:0 language=eng -metadata:s:s:0 title="English""
    set "DISPOSITIONS=!DISPOSITIONS! -disposition:s:0 default"
    set /a SUB_COUNT+=1
    rem forced?
    echo !FNAME! | findstr /i "forced" >nul && set "DISPOSITIONS=!DISPOSITIONS! -disposition:s:0 forced"
)

rem ---- Collect all .srt files from Subs (quoted) ------------------
set "SRT_LIST="
for /f "delims=" %%A in ('dir /b /on "!SUBS_DIR!\*.srt" 2^>nul') do (
    set "SRT_LIST=!SRT_LIST! "!SUBS_DIR!\%%A""
)

rem ---- Process each subtitle --------------------------------------
for %%F in (!SRT_LIST!) do (
    set "FNAME=%%~nF"
    set "DISP="
    set /a "META_IDX=SUB_COUNT-1"

    rem --- Language: last 3 chars ---
    set "LANG=!FNAME:~-3!"
    if /i "!LANG!"=="srt" set "LANG=und"
    if "!LANG!"==".HI" (
        set "DISP=hearing_impaired"
        set "LANG=und"
    )

    rem --- Disposition: hearing_impaired ---
    echo !FNAME! | findstr /i "SDH" >nul && set "DISP=hearing_impaired"
    
    rem --- Disposition: forced ---
    echo !FNAME! | findstr /i "forced" >nul && set "DISP=forced"

    if defined DISP set "DISPOSITIONS=!DISPOSITIONS! -disposition:s:!META_IDX! !DISP!"

    rem --- Title: everything before the last 4 chars (.xxx) ---
    set "TITLE=!FNAME:~0,-4!"
    rem Special case: Last three characters ".HI" (hearing impaired marker)
    echo "!FNAME:~-3!" | findstr "\.HI" >nul
    if not errorlevel 1 (
        echo !FNAME! | findstr /i "eng" >nul
        if not errorlevel 1 (
            set "LANG=eng"
            set "TITLE=English (SDH)"
        ) else (
            rem Handle languages other than English - extract 3-char code before .HI
            set "TITLE=SDH"
            set "LANG=!FNAME:~-6,-3!"
        )
    )

    rem --- Special case: English override ---
    echo !FNAME! | findstr /i "English" >nul && set "LANG=eng" && set "TITLE=English"

    rem Trim trailing space
    if "!TITLE:~-1!"==" " set "TITLE=!TITLE:~0,-1!"
    if "!TITLE!"=="" set "TITLE="
    rem Append (SDH) to the title if hearing_impaired and SDH is not already in name
    if "!DISP!"=="hearing_impaired" (
        echo "!TITLE!" | findstr /i "SDH" >nul
        if errorlevel 1 (
            echo "!FNAME!" | findstr /i "SDH" >nul
            if errorlevel 1 set "TITLE=!TITLE! (SDH)"
        )
    )
    rem --- Build metadata ---
    set "THIS_META=-metadata:s:s:!META_IDX! language=!LANG!"
    if defined TITLE set "THIS_META=!THIS_META! -metadata:s:s:!META_IDX! title="!TITLE!""
    set "METADATA=!METADATA! !THIS_META!"

    rem --- Input & map ---
    set "INPUTS=!INPUTS! -i %%F"
    set "MAPS=!MAPS! -map !SUB_COUNT!"
    set /a SUB_COUNT+=1
)

rem ---- Global comment ---------------------------------------------
set "COMMENTS=-metadata comment="Re-encoded ^& muxed by ScreenPhantom 📺👻""
set "COMMENTS=!COMMENTS! -metadata:s:v:0 comment="Re-encoded ^& muxed by ScreenPhantom 📺👻""

rem ---- Final command ----------------------------------------------
set "FFMPEG_CMD=ffmpeg !INPUTS! !CODECS! !MAPS! !METADATA! !DISPOSITIONS! -map_metadata 0 -map_chapters 0 !COMMENTS! -y "!OUTPUT_FILE!""

rem ---- Show command -----------------------------------------------
echo.
echo ================================================================
echo FFmpeg Command (copy and paste into CMD):
echo ================================================================
echo !FFMPEG_CMD!
echo ================================================================
echo.
