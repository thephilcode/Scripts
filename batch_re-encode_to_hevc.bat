@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

::v2.0
::This version is modified to skip re-encoding if output file already exists

set "logfile=reencode_log.txt"
echo Starting HEVC re-encoding at %date% %time% > "%logfile%"
mkdir temp_hevc
set "error_occurred=0"

REM Loop 1: Encode all to temp, skipping files with x265/h265
for %%f in (*.mp4 *.mkv) do (
    set "orig=%%~nf"
    set "ext=%%~xf"
    set "newname=!orig:x264=x265!"
    set "newname=!newname:h264=h265!!ext!"
    REM Skip if filename already contains x265 or h265
    echo !orig! | findstr /i "x265 h265" >nul
    if !errorlevel! equ 0 (
        echo Skipping !orig!!ext! - already processed >> "%logfile%"
    ) else if exist "temp_hevc\!newname!" (
        echo Skipping !orig!!ext! - already processed >> "%logfile%" 
    ) else (
        echo Encoding !orig!!ext! to temp_hevc\!newname! >> "%logfile%"
        ffmpeg -i "!orig!!ext!" -sub_charenc UTF-8 -map 0 -map_chapters 0 -map_metadata 0 -c:v libx265 -preset medium -crf 28 -x265-params "bframes=4:rc-lookahead=40:ref=4" -c:a copy -c:s copy -movflags +faststart -metadata comment="Re-encoded by ScreenPhantom 📺👻" -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻" "temp_hevc\!newname!" -y
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
                move "temp_hevc\!newname!" "!newname!"
                echo Replaced !orig!!ext! with !newname! >> "%logfile%"
            )
        )
    )
    rmdir /s /q temp_hevc
    echo All done! Check %logfile% for details. >> "%logfile%"
) else (
    echo Errors occurred—check outputs in temp_hevc and %logfile%. >> "%logfile%"
    REM Keep temp_hevc for manual inspection
)
echo Done. Log saved to %logfile%.
pause