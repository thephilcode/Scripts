@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

::v2.1 - 2025-12-10
::This version uses ffprobe instead of the filename to check if a video file is already hevc or not. A more reliable approach

set "logfile=reencode_log.txt"
echo Starting HEVC re-encoding at %date% %time% > "%logfile%"
if not exist "temp_hevc\" (
    mkdir "temp_hevc"
    echo Created temp_hevc folder >> "%logfile%"
) else (
    echo temp_hevc already exists, skipping creation >> "%logfile%"
)
set "error_occurred=0"

REM Loop 1: Encode all to temp, skipping files with x265/h265
for %%f in (*.mp4 *.mkv) do (
    set "orig=%%~nf"
    set "ext=%%~xf"
    set "newname=!orig:x264=x265!"
    set "newname=!newname:h264=h265!.mkv"
    REM Skip if file is already hevc
    echo !orig! | findstr /i "x265 h265" >nul
    if !errorlevel! equ 0 (
        echo Skipping !orig!!ext! - already processed >> "%logfile%"
    ) else if exist "temp_hevc\!newname!" (
        echo Skipping !orig!!ext! - already processed >> "%logfile%" 
    ) else (
        echo Encoding !orig!!ext! to temp_hevc\!newname! >> "%logfile%"
        ffmpeg -i "!orig!!ext!" -sub_charenc UTF-8 -map 0:v -map 0:a -map 0:s? -map_chapters 0 -map_metadata 0 -c:v libx265 -preset medium -crf 28 -x265-params "bframes=4:rc-lookahead=40:ref=4" -c:a copy -c:s subrip -movflags +faststart -metadata comment="Re-encoded by ScreenPhantom 📺👻" -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻" "temp_hevc\!newname!" -y
        if !errorlevel! neq 0 (
            echo ERROR encoding !orig!!ext! >> "%logfile%"
            set "error_occurred=1"
        ) else (
            echo Successfully encoded !orig!!ext! to !newname! >> "%logfile%"
        )
    )
)

REM If no errors, proceed to replace
if %error_occurred%==0 (
    REM Loop 2: Delete originals and move new ones
    for %%f in (*.mp4 *.mkv) do (
        set "orig=%%~nf"
        set "ext=%%~xf"
        echo !orig! | findstr /i "x265 h265" >nul
        if !errorlevel! equ 0 (
            echo Skipping replacement for !orig!!ext! >> "%logfile%"
        ) else (
            set "newname=!orig:x264=x265!"
            set "newname=!newname:h264=h265!!ext!"
            if exist "temp_hevc\!newname!" (
                del "!orig!!ext!"
                move "temp_hevc\!newname!" ./
                echo Replaced !orig!!ext! with !newname! >> "%logfile%"
            )
        )
    )
    rmdir temp_hevc
    echo All done! Check %logfile% for details. >> "%logfile%"
) else (
    echo Errors occurred—check outputs in temp_hevc and %logfile%. >> "%logfile%"
    REM Keep temp_hevc for manual inspection
)
echo Done. Log saved to %logfile%.
pause