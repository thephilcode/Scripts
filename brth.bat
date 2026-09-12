@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: v2.7 - 2026-07-14
:: Add variable bitrate option for minimum audio file sie with maximum quality
:: Fix error when converting Dolby SUrround Sound to OPUS by adding audio channel layout check to dynamically set layout 

set "logfile=reencode_log.txt"
echo Starting HEVC re-encoding at %date% %time% > "%logfile%"
if not exist "temp_hevc\" (
    mkdir "temp_hevc"
    echo Created temp_hevc folder >> "%logfile%"
) else (
    echo temp_hevc already exists, skipping creation >> "%logfile%"
)
set "error_occurred=0"
set "scale_arg="

:: simple argument parsing so we don't repeat code for "%~1" and "%~2"
for %%A in (%*) do (
    if /i "%%~A"=="--rescale"      set rescale=1 & set "scale_arg=-vf scale=1280:-2 "
    if /i "%%~A"=="-r"             set rescale=1 & set "scale_arg=-vf scale=1280:-2 "
    if /i "%%~A"=="--force"        set force_reencode=1
    if /i "%%~A"=="-f"             set force_reencode=1
)

if defined force_reencode echo Forced re-encoding of HEVC videos enabled >> "%logfile%" 
if defined rescale echo Rescaling to 720P enabled >> "%logfile%"

set "meta_title="
set "meta_comments=-metadata comment="Re-encoded by ScreenPhantom 📺👻""
set "meta_comments=!meta_comments! -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻""

REM Loop 1: Encode all to temp, skipping hevc files
for %%f in (*.mkv *.mp4) do (
    set "orig=%%~nf"
    set "ext=%%~xf"
    set "newname=!orig:AV1=HEVC!"
    set "newname=!newname:AVC=HEVC!"
    set "newname=!newname:x264=x265!"
    set "newname=!newname:h264=h265!"
    set "newname=!newname:AAC=OPUS!"
    set "newname=!newname:aac=opus!"
    if defined rescale (
        set "newname=!newname:1080p=720p!"
        set "newname=!newname:1080P=720P!"
    )
    set "newname=!newname!.mkv"
    :: Set subtitle codec
    if "!ext!"==".mkv" (
        set "subcodec=copy"
    ) else (
        set "subcodec=subrip"
    )

    REM Build dynamic bitrate arguments for each audio stream based on channel layout
    set "audio_maps="
    set "audio_args="
    set /a stream_idx=0
    for /f "usebackq tokens=*" %%d in (`ffprobe -v error -select_streams a -show_entries stream^=channels -of default^=noprint_wrappers^=1:nokey^=1 "%%f" 2^>nul`) do (
        set "this_bitrate=96k"
        REM Set bitrate to 192k if audio is surround sound
        if %%d GEQ 6 (
            set "this_bitrate=192k"
        )
        set "audio_args=!audio_args! -b:a:!stream_idx! !this_bitrate! -ac:a:!stream_idx! %%d"
        set "audio_maps=!audio_maps! -map 0:a:!stream_idx!"
        set /a stream_idx+=1
    )
    if !audio_maps! == "" (
        set "audio_maps=-map 0:a:?"
    )

    REM Skip if file is already hevc (unless forcing)
    set "is_hevc=0"
    if not defined force_reencode (
        ffprobe -c:v hevc -i "%%f" 2>nul 1>nul
        if !errorlevel! equ 0 (
            set "is_hevc=1"
        )
    )
    if !is_hevc! equ 1 (
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
        echo !newname! | findstr /i "GalaxyTV" >nul && set "meta_title=-metadata title="!newname:~0,-4!" "
        if !skip_encode! equ 0 (
            if exist "!orig!.srt" (
                echo Encoding !orig!!ext! and muxing !orig!.srt to temp_hevc\!newname! >> "%logfile%"
                ffmpeg -i "!orig!!ext!" -i "!orig!.srt" -map 0:v !audio_maps! -map 0:s? -map 1 -map_chapters 0 -map_metadata 0 !scale_arg!-c:v libx265 -preset medium -crf 28 -pix_fmt yuv420p10le -x265-params "bframes=4:rc-lookahead=40:ref=4:pmode=1:pme=1" -c:a libopus !audio_args! -c:s !subcodec! -movflags +faststart -metadata:s:s:0 language=eng !meta_title!!meta_comments! "temp_hevc\!newname!" -y
                
                if !errorlevel! neq 0 (
                    echo ERROR encoding !orig!!ext! and muxing !orig!.srt >> "%logfile%"
                    set "error_occurred=1"
                ) else (
                    echo Successfully encoded and muxed !orig!!ext! and !orig!.srt to !newname! >> "%logfile%"
                ) 
            ) else (
                echo Encoding !orig!!ext! to temp_hevc\!newname! >> "%logfile%"
                ffmpeg -i "!orig!!ext!" -map 0:v !audio_maps! -map 0:s? -map_chapters 0 -map_metadata 0 !scale_arg!-c:v libx265 -preset medium -crf 28 -pix_fmt yuv420p10le -x265-params "bframes=4:rc-lookahead=40:ref=4:pmode=1:pme=1" -c:a libopus !audio_args! -c:s !subcodec! -movflags +faststart !meta_title!!meta_comments! "temp_hevc\!newname!" -y
                
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
    for %%f in (*.mkv *.mp4) do (
        set "orig=%%~nf"
        set "ext=%%~xf"
        set "is_hevc=0"
        if not defined force_reencode (
            ffprobe -c:v hevc -i "%%f" 2>nul 1>nul
            if !errorlevel! equ 0 (
                set "is_hevc=1"
            )
        )
        if !is_hevc! equ 1 (
            echo Skipping replacement for !orig!!ext! >> "%logfile%"
        ) else (
            set "newname=!orig:AV1=HEVC!"
            set "newname=!newname:AVC=HEVC!"
            set "newname=!newname:x264=x265!"
            set "newname=!newname:h264=h265!"
            set "newname=!newname:AAC=OPUS!"
            set "newname=!newname:aac=opus!"
            if !rescale! equ 1 (
                set "newname=!newname:1080p=720p!"
                set "newname=!newname:1080P=720P!"
            )
            set "newname=!newname!!ext!"
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