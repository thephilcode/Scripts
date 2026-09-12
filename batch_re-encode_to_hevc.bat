@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "logfile=reencode_log.txt"
echo Starting HEVC re-encoding at %date% %time% > "%logfile%"
mkdir temp_hevc
set "error_occurred=0"

REM Loop 1: Encode all to temp, skipping files with x265/h265
for %%f in (*.mp4 *.mkv) do (
    set "orig=%%~nf"
    set "ext=%%~xf"
    REM Skip if filename already contains x265 or h265
    echo !orig! | findstr /i "x265 h265" >nul
    if !errorlevel! equ 0 (
        echo Skipping !orig!!ext! - already processed >> "%logfile%"
    ) else (
        set "newname=!orig:x264=x265!"
        set "newname=!newname:h264=h265!.mkv"
        echo Encoding !orig!!ext! to temp_hevc\!newname! >> "%logfile%"
        ffmpeg -i "!orig!!ext!" -sub_charenc UTF-8 -map 0:v -map 0:a -map 0:s? -map_chapters 0 -map_metadata 0 -c:v libx265 -preset medium -crf 28 -x265-params "bframes=4:rc-lookahead=40:ref=4" -c:a copy -c:s srt -metadata comment="Re-encoded by ScreenPhantom 📺👻" -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻" "temp_hevc\!newname!" -y
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