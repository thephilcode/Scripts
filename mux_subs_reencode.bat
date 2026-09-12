@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: v1.10 - 2025-11-12
:: This revision fixes the previous issue of splitting subtitle names that had spaces in them.

rem --------------------------------------------------------------
rem  CONFIG
rem --------------------------------------------------------------
set "SUBS_DIR=Subs"
set "HEVC_PRESET=medium"
set "HEVC_CRF=28"
rem --------------------------------------------------------------

rem ---- get the video file -------------------------------------------------
set "VIDEO_FILE=%~1"
if "%VIDEO_FILE%"=="" (
    echo *** ERROR: No video file supplied.
    echo    Drag-and-drop the video onto this .bat or run:
    echo    %~nx0 "C:\path\to\your movie.mkv"
    pause & exit /b 1
)
if not exist "%VIDEO_FILE%" (
    echo *** ERROR: Video file not found: "%VIDEO_FILE%"
    pause & exit /b 1
)

rem ---- output name: replace x264 → x265, force .mkv -----------------------
set "BASE=%~n1"
set "EXT=.mkv"
set "OUTBASE=!BASE!"
set "tmp=!BASE!"
:replace
if defined tmp (
    set "tmp=!tmp:x264=x265!"
    if "!tmp!"=="!BASE!" (
        set "tmp=!tmp:X264=X265!"
        if "!tmp!"=="!BASE!" (
            set "OUTBASE=!BASE!-x265"
            goto :done_replace
        )
    )
    set "OUTBASE=!tmp!"
    goto :done_replace
)
:done_replace
set "OUTPUT_FILE=!OUTBASE!!EXT!"
echo Output file: !OUTPUT_FILE!

rem ---- main subtitle (same name as video) --------------------------------
set "MAIN_SUB=!BASE!.srt"
if exist "!MAIN_SUB!" (
    set "MAIN_SUB=!MAIN_SUB!"
) else (
    set "MAIN_SUB="
    echo Warning: No main subtitle "!BASE!.srt"
)

rem ---- Subs folder --------------------------------------------------------
if not exist "!SUBS_DIR!\" (
    echo *** ERROR: Folder "!SUBS_DIR!" not found.
    pause & exit /b 1
)

rem ---- build FFmpeg pieces ------------------------------------------------
set "INPUTS=-i "!VIDEO_FILE!""
set "MAPS=-map 0"
set "CODECS=-c:v libx265 -preset %HEVC_PRESET% -crf %HEVC_CRF% -c:a copy -c:s copy"
set "METADATA="
set "DISPOSITIONS="
set "SUB_COUNT=1"

rem ---- add main subtitle (track 0) ---------------------------------------
if defined MAIN_SUB (
    set "INPUTS=!INPUTS! -i "!MAIN_SUB!""
    set "MAPS=!MAPS! -map !SUB_COUNT!"
    set "METADATA=!METADATA! -metadata:s:s:0 language=eng"
    set "DISPOSITIONS=!DISPOSITIONS! -disposition:s:0 default"
    set /a SUB_COUNT+=1

    rem forced?
    set "chk=!MAIN_SUB!"
    set "chk=!chk:forced=!"
    set "chk=!chk:FORCED=!"
    if not "!chk!"=="!MAIN_SUB!" set "DISPOSITIONS=!DISPOSITIONS! -disposition:s:0 forced"
)

rem ---- collect *all* .srt files from Subs (quoted, one per line) ----------
set "SRT_LIST="
for /f "delims=" %%A in ('dir /b /on "!SUBS_DIR!\*.srt"') do (
    set "SRT_LIST=!SRT_LIST! "!SUBS_DIR!\%%A""
)

rem ---- process every subtitle from Subs -----------------------------------
for %%F in (!SRT_LIST!) do (
    set "FNAME=%%~nF"

    rem language code – last 3 chars, fallback und
    set "LANG=!FNAME:~-3!"
    if /i "!LANG!"=="srt" set "LANG=und"
    rem special case: any "English" in the name → eng
    echo !FNAME! | findstr /i "English" >nul && set "LANG=eng"

    rem forced?
    set "DISP="
    set "chk=!FNAME!"
    set "chk=!chk:forced=!"
    set "chk=!chk:FORCED=!"
    if not "!chk!"=="!FNAME!" set "DISP=forced"

    rem add to command
    set "INPUTS=!INPUTS! -i %%F"
    set "MAPS=!MAPS! -map !SUB_COUNT!"
    set /a "META_IDX=SUB_COUNT-1"
    set "METADATA=!METADATA! -metadata:s:s:!META_IDX! language=!LANG!"
    if defined DISP set "DISPOSITIONS=!DISPOSITIONS! -disposition:s:!META_IDX! !DISP!"

    set /a SUB_COUNT+=1
)

rem ---- comment metadata ---------------------------------------------------
set "COMMENTS=-metadata comment="Re-encoded and muxed by ScreenPhantom""
set "COMMENTS=!COMMENTS! -metadata:s:v:0 comment="Re-encoded and muxed by ScreenPhantom""

rem ---- final command ------------------------------------------------------
set "FFMPEG_CMD=ffmpeg !INPUTS! !CODECS! !MAPS! !METADATA! !DISPOSITIONS! -map_metadata 0 -map_chapters 0 !COMMENTS! -y "!OUTPUT_FILE!""

rem ---- show it ------------------------------------------------------------
echo.
echo ================================================================
echo Generated FFmpeg command (copy-paste after you check it):
echo ================================================================
echo !FFMPEG_CMD!
echo ================================================================
echo.
pause