@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: v2.5 - 2025-12-29
:: Skips unnecessary re-encoding of subtitles if input files are already mkv

set "logfile=reencode_log.txt"
echo Starting HEVC re-encoding at %date% %time% > "%logfile%"
if not exist "temp_hevc\" (
    mkdir "temp_hevc"
    echo Created temp_hevc folder >> "%logfile%"
) else (
    echo temp_hevc already exists, skipping creation >> "%logfile%"
)
set "error_occurred=0"

REM Loop 1: Encode all to temp, skipping hevc files
for %%f in (*.mp4 *.mkv) do (
    set "orig=%%~nf"
    set "ext=%%~xf"
    set "newname=!orig:AV1=HEVC!"
    set "newname=!newname:AVC=HEVC!"
    set "newname=!newname:x264=x265!"
    set "newname=!newname:h264=h265!.mkv"
    :: Set subtitle codec
    if "!ext!"==".mkv" (
        set "subcodec=copy"
    ) else (
        set "subcodec=subrip"
    )
    REM Skip if file is already hevc
    ffprobe -c:v hevc -i "%%f" 2>nul 1>nul
    if !errorlevel! equ 0 (
        echo Skipping !orig!!ext! - already processed >> "%logfile%"
    ) else (
        REM Check if output exists and has same duration as input
        set "skip_encode=0"
        if exist "temp_hevc\!newname!" (
            REM Get input duration
            for /f "usebackq tokens=*" %%d in (`ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "!orig!!ext!" 2^>nul`) do set "input_duration=%%d"
            REM Get output duration
            for /f "usebackq tokens=*" %%d in (`ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 "temp_hevc\!newname!" 2^>nul`) do set "output_duration=%%d"
            REM Compare durations using PowerShell (allow 0.5 second tolerance for rounding)
            if defined input_duration if defined output_duration (
                set "ps_in=!input_duration!"
                set "ps_out=!output_duration!"
                powershell -command "$in=[double]$env:ps_in; $out=[double]$env:ps_out; $diff=[Math]::Abs($in - $out); if ($diff -le 0.5) { exit 0 } else { exit 1 }" >nul 2>&1
                if !errorlevel! equ 0 (
                    set "skip_encode=1"
                    echo Skipping !orig!!ext! - output exists with matching duration >> "%logfile%"
                ) else (
                    echo Output file exists but duration mismatch, will re-encode >> "%logfile%"
                )
                set "ps_in="
                set "ps_out="
            )
        )
        if !skip_encode! equ 0 (
            if exist "!orig!.srt" (
                echo Encoding !orig!!ext! and muxing !orig!.srt to temp_hevc\!newname! >> "%logfile%"
                ffmpeg -i "!orig!!ext!" -sub_charenc UTF-8 -i "!orig!.srt" -map 0:v -map 0:a -map 0:s? -map 1 -map_chapters 0 -map_metadata 0 -c:v libx265 -preset medium -crf 28 -x265-params "bframes=4:rc-lookahead=40:ref=4" -c:a copy -c:s !subcodec! -movflags +faststart -metadata:s:s:0 language=eng -metadata comment="Re-encoded by ScreenPhantom 📺👻" -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻" "temp_hevc\!newname!" -y
                if !errorlevel! neq 0 (
                    echo ERROR encoding !orig!!ext! and muxing !orig!.srt >> "%logfile%"
                    set "error_occurred=1"
                ) else (
                    echo Successfully encoded and muxed !orig!!ext! and !orig!.srt to !newname! >> "%logfile%"
                ) 
            ) else (
                echo Encoding !orig!!ext! to temp_hevc\!newname! >> "%logfile%"
                ffmpeg -i "!orig!!ext!" -sub_charenc UTF-8 -map 0:v -map 0:a -map 0:s? -map_chapters 0 -map_metadata 0 -c:v libx265 -preset medium -crf 28 -x265-params "bframes=4:rc-lookahead=40:ref=4" -c:a copy -c:s !subcodec! -movflags +faststart -metadata comment="Re-encoded by ScreenPhantom 📺👻" -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻" "temp_hevc\!newname!" -y
                if !errorlevel! neq 0 (
                    echo ERROR encoding !orig!!ext! >> "%logfile%"
                    set "error_occurred=1"
                ) else (
                    echo Successfully encoded !orig!!ext! to !newname! >> "%logfile%"
                )
            )
        )
    )
)

REM If no errors, proceed to replace
if %error_occurred%==0 (
    REM Loop 2: Delete originals and move new ones
    for %%f in (*.mp4 *.mkv) do (
        set "orig=%%~nf"
        set "ext=%%~xf"
        ffprobe -c:v hevc -i "%%f" 2>nul 1>nul
        if !errorlevel! equ 0 (
            echo Skipping replacement for !orig!!ext! >> "%logfile%"
        ) else (
            set "newname=!orig:AV1=HEVC!"
            set "newname=!newname:AVC=HEVC!"
            set "newname=!newname:x264=x265!"
            set "newname=!newname:h264=h265!!ext!"
            if exist "temp_hevc\!newname!" (
                del "!orig!!ext!"
                if exist "!orig!.srt" (
                    del "!orig!.srt"
                )
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