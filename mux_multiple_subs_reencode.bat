@echo off
setlocal EnableDelayedExpansion

:: v1.0
:: mux_multiple_subs_reencode.bat

:: Configuration
set "VIDEO_FILE=%~1"
set "SUBS_DIR=Subs"
set "HEVC_PRESET=medium"
set "HEVC_CRF=23"

:: Check if video file is provided and exists
if "%VIDEO_FILE%"=="" (
    echo Error: No video file provided! Drag and drop a video file onto this script.
    exit /b 1
)
if not exist "%VIDEO_FILE%" (
    echo Error: Video file '%VIDEO_FILE%' not found!
    exit /b 1
)

:: Derive output filename with x264 -> x265 replacement
set "BASE_NAME=%~n1"
set "EXT=%~x1"
set "LOWER_BASE=!BASE_NAME!"
for /f "tokens=* delims=" %%A in ("!LOWER_BASE!") do set "LOWER_BASE=%%A"
echo !LOWER_BASE! | findstr /i "x264" >nul
if !errorlevel! == 0 (
    :: Replace first x264 (case-insensitive) with x265
    set "OUTPUT_BASE=!BASE_NAME:x264=x265!"
    set "OUTPUT_BASE=!OUTPUT_BASE:X264=X265!"
) else (
    set "OUTPUT_BASE=!BASE_NAME!-x265"
)
set "OUTPUT_FILE=!OUTPUT_BASE!!EXT!"

:: Check if subtitle file with same name exists
set "MAIN_SUB=!BASE_NAME!.srt"
if not exist "%MAIN_SUB%" (
    echo Warning: No subtitle file '%MAIN_SUB%' found in parent folder. Proceeding without default subtitle.
    set "MAIN_SUB="
)

:: Check if Subs folder exists
if not exist "%SUBS_DIR%\" (
    echo Error: Subtitles folder '%SUBS_DIR%' not found!
    exit /b 1
)

:: Initialize FFmpeg command parts
set "INPUTS=-i "%VIDEO_FILE%""
set "MAPS=-map 0"
set "CODECS=-c:v libx265 -preset %HEVC_PRESET% -crf %HEVC_CRF% -c:a copy -c:s copy"
set "DISPOSITIONS="
set "METADATA=-metadata:s:s"
set SUB_COUNT=1
set "DEFAULT_SET=0"

:: Add main subtitle file (if exists) as first input and set as default
if exist "%MAIN_SUB%" (
    set "INPUTS=%INPUTS% -i "%MAIN_SUB%""
    set "MAPS=%MAPS% -map 1"
    
    :: Language (assume eng for main)
    set "METADATA=%METADATA%:0 language=eng"
    
    :: Default disposition
    set "DISPOSITIONS=%DISPOSITIONS% -disposition:s:0 default"
    set "DEFAULT_SET=1"
    
    :: Check for forced in main sub filename
    echo %MAIN_SUB% | findstr /i "forced" >nul
    if !errorlevel! == 0 (
        set "DISPOSITIONS=%DISPOSITIONS% -disposition:s:0 forced"
    )
)

:: Process subtitle files in Subs folder
for %%F in ("%SUBS_DIR%\*.srt") do (
    set "SUB_FILE=%%F"
    set "FILENAME=%%~nF"
    
    :: Extract three-letter language code (last three characters before .srt)
    set "LANG=!FILENAME:~-3!"
    if "!LANG!"=="srt" set "LANG=und"
    
    :: Check for forced
    set "DISP="
    echo !FILENAME! | findstr /i "forced" >nul
    if !errorlevel! == 0 set "DISP=forced"
    
    set "INPUTS=!INPUTS! -i "!SUB_FILE!""
    set "MAPS=!MAPS! -map !SUB_COUNT!"
    set "METADATA=!METADATA!:!SUB_COUNT! language=!LANG!"
    if defined DISP set "DISPOSITIONS=!DISPOSITIONS! -disposition:s:!SUB_COUNT! !DISP!"
    set /a SUB_COUNT+=1
)

:: Build full FFmpeg command (include -map_metadata -1 to strip original metadata if desired, or 0 to copy)
set "FFMPEG_CMD=ffmpeg %INPUTS% %CODECS% %MAPS% %METADATA% %DISPOSITIONS% -map_metadata 0 -y "%OUTPUT_FILE%""

:: Print the command
echo Generated FFmpeg command (reencoding to HEVC):
echo %FFMPEG_CMD%
echo.
echo Copy and paste the above command to run it after inspection/tweaks (e.g., adjust -crf for quality).
pause