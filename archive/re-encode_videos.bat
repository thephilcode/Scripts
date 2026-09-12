@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: Check if FFmpeg is installed
where ffmpeg >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo FFmpeg is not installed or not found in PATH. Please install FFmpeg and add it to your system PATH.
    pause
    exit /b
)

:: Set output directory on Desktop
set "OutputDir=%USERPROFILE%\Desktop\ConvertedVideos"
if not exist "%OutputDir%" mkdir "%OutputDir%"

:: Check if a file or folder was dropped
if "%~1"=="" (
    echo No file or folder was dropped. Drag and drop a video file or folder onto this script.
    pause
    exit /b
)

:: Handle dropped item
if exist "%~1\*" (
    :: Dropped item is a folder
    call :ProcessFolder "%~1"
) else (
    :: Dropped item is a file
    call :ProcessFile "%~1"
)

echo Conversion complete. Output files are in %OutputDir%
pause
exit /b

:ProcessFolder
:: Process all video files in the folder (common video extensions)
for %%F in ("%~1\*.mp4" "%~1\*.mkv" "%~1\*.avi" "%~1\*.mov" "%~1\*.wmv") do (
    call :ProcessFile "%%F"
)
exit /b

:ProcessFile
:: Check if file exists
if not exist "%~1" exit /b

:: Get the video codec using ffprobe
for /f "tokens=*" %%C in ('ffprobe -v error -select_streams v:0 -show_entries stream^=codec_name -of default^=noprint_wrappers^=1:nokey^=1 "%~1"') do set "Codec=%%C"

:: Skip if already H.264
if /i "!Codec!"=="h264" (
    echo Skipping "%~1" - already encoded in H.264
    exit /b
)

:: Skip if codec is not HEVC or other (to avoid processing non-video or unsupported codecs)
if /i not "!Codec!"=="hevc" (
    echo Skipping "%~1" - codec "!Codec!" is not HEVC or H.264
    exit /b
)

:: Set output file path (append _converted to filename)
set "OutputFile=%OutputDir%\%~n1_converted%~x1"

:: Perform conversion to H.264 using FFmpeg
echo Converting "%~1" to H.264...
ffmpeg -i "%~1" -map 0 -metadata comment="Re-encoded by ScreenPhantom 📺👻" -c:v libx264 -preset fast -crf 23 -c:a copy -c:s copy -disposition:s:0 default "%OutputFile%"
if %ERRORLEVEL% equ 0 (
    echo Successfully converted "%~1" to "%OutputFile%"
) else (
    echo Failed to convert "%~1"
)
exit /b