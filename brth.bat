@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: v3.4 - 2026.11.23
:: Add completion markers to avoid revalidating successfully encoded files
:: Validate unmarked existing outputs by decoding all video and audio streams
:: Compare actual audio/video packet end times to reject cleanly truncated outputs
:: Calculate packet end times inline so validation stays in this script
:: Add preservation of attached_pic type video streams
:: Preserve all source stream types, including attachments and data streams
:: Add comment to each reencoded video and audio stream instead of just the first ones
:: Improve GalaxyTV name substitution by probing for meta title instead of searching filename
:: Improve subtitle codec selection by probing for subtitle streams and setting arguments for each stream based on codec name
:: Exit with errorlevel 1 if any encoding errors occurred, otherwise exit with errorlevel 0 instead of pausing at the end
:: Change scale argument to scale=-2:720 for better compatibility with 16:9 aspect ratio videos

set "logfile=reencode_log.txt"
set "HEVC_PRESET=medium"
set "HEVC_CRF=28"
set "PIX_FORMAT=-pix_fmt yuv420p10le"
set "HEVC_PARAMS=-x265-params bframes=4:rc-lookahead=40:ref=4"

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
    if /i "%%~A"=="--rescale"      set rescale=1 & set "scale_arg=-vf scale=-2:720 "
    if /i "%%~A"=="-r"             set rescale=1 & set "scale_arg=-vf scale=-2:720 "
    if /i "%%~A"=="--force"        set force_reencode=1
    if /i "%%~A"=="-f"             set force_reencode=1
    if /i "%%~A"=="--skip"        set skip_existing=1
    if /i "%%~A"=="-s"             set skip_existing=1
)

if defined force_reencode echo Forced re-encoding of HEVC videos enabled >> "%logfile%" 
if defined rescale echo Rescaling to 720P enabled >> "%logfile%"
if defined skip_existing echo Skipping re-encoding of existing HEVC videos enabled >> "%logfile%"

set "meta_title="
set "meta_comments=-metadata comment="Re-encoded by ScreenPhantom 📺👻""

REM Loop 1: Encode all to temp, skipping hevc files
for %%f in (*.avi *.mkv *.mp4) do (
    set "orig=%%~nf"
    set "ext=%%~xf"
    set "newname=!orig:AV1=HEVC!"
    set "newname=!newname:AVC=HEVC!"
    set "newname=!newname:x264=x265!"
    set "newname=!newname:h264=h265!"
    set "newname=!newname:AAC=OPUS!"
    set "newname=!newname:aac=opus!"
    set "newname=!newname:FLAC=OPUS!"
    set "newname=!newname:flac=opus!"
    set "newname=!newname:DDP=OPUS!"
    set "newname=!newname:ddp=opus!"
    if defined rescale (
        set "newname=!newname:1080p=720p!"
        set "newname=!newname:1080P=720P!"
    )
    set "newname=!newname!.mkv"
    
    REM Build subtitle stream arguments
    set "sub_args="
    set /a sub_stream_idx=0
    for /f "usebackq tokens=*" %%d in (`ffprobe -v error -select_streams s -show_entries stream^=codec_name -of default^=noprint_wrappers^=1:nokey^=1 "%%f" 2^>nul`) do (
        set "this_subcodec=copy"
        if /i "%%d" == "ssa" ( set "this_subcodec=ass" )
        if /i "%%d" == "mov_text" ( set "this_subcodec=subrip" )
        if /i "%%d" == "webvtt" ( set "this_subcodec=subrip" )
        set "sub_args=!sub_args! -c:s:!sub_stream_idx! !this_subcodec!"
        set /a sub_stream_idx+=1
    )
    if not defined sub_args ( set "sub_args=-c:s copy" )

    REM Build dynamic bitrate arguments for each audio stream based on channel layout
    set "audio_args="
    set /a audio_stream_idx=0
    for /f "usebackq tokens=*" %%d in (`ffprobe -v error -select_streams a -show_entries stream^=channels -of default^=noprint_wrappers^=1:nokey^=1 "%%f" 2^>nul`) do (
        set "this_bitrate=96k"
        REM Set bitrate to 192k if audio is surround sound
        if %%d GEQ 6 (
            set "this_bitrate=192k"
        )
        set "audio_args=!audio_args! -c:a:!audio_stream_idx! libopus -vbr on -b:a:!audio_stream_idx! !this_bitrate! -ac:a:!audio_stream_idx! %%d"
        set "meta_comments=!meta_comments! -metadata:s:a:!audio_stream_idx! comment="Re-encoded by ScreenPhantom 📺👻""
        set /a audio_stream_idx+=1
    )

    REM Preserve codec of video streams with disposition attached_pic if any
    set "video_args="
    set "video_stream_idx=0"
    for /f "usebackq tokens=*" %%d in (`ffprobe -v error -select_streams v -show_entries disposition^=attached_pic -of default^=noprint_wrappers^=1:nokey^=1 "%%f" 2^>nul`) do (
        if %%d equ 1 (
            set "video_args=!video_args! -c:v:!video_stream_idx! copy"
        ) else (
            set "video_args=!video_args! !scale_arg!-c:v:!video_stream_idx! libx265 -preset !HEVC_PRESET! -crf !HEVC_CRF! !PIX_FORMAT! !HEVC_PARAMS!"
            set "meta_comments=!meta_comments! -metadata:s:v:!video_stream_idx! comment="Re-encoded by ScreenPhantom 📺👻""
        )
        set /a video_stream_idx+=1
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
        REM Check if output exists and was completely written and valid
        set "skip_encode=0"
        if defined skip_existing (
            set "skip_encode=1"
            echo Skipping re-encoding of !orig!!ext! due to --skip argument >> "%logfile%"
        ) else (
            if exist "temp_hevc\!newname!" (
                if exist "temp_hevc\!newname!.complete" (
                    set "skip_encode=1"
                    echo Skipping !orig!!ext! - completion marker found >> "%logfile%"
                ) else (
                    REM Legacy or interrupted output: decode every video and audio stream
                    echo Checking existing temp_hevc\!newname! by decoding it fully >> "%logfile%"
                    ffmpeg -hide_banner -loglevel error -xerror -err_detect explode ^
                        -i "temp_hevc\!newname!" ^
                        -map 0:v? -map 0:a? ^
                        -f null NUL >nul 2>&1

                    if !errorlevel! neq 0 (
                        set "skip_encode=0"
                        del "temp_hevc\!newname!.complete" 2>nul
                        echo Existing temp_hevc\!newname! failed decoding, re-encoding >> "%logfile%"
                    ) else (
                        set "MEDIA_SOURCE=!CD!\!orig!!ext!"
                        set "MEDIA_OUTPUT=!CD!\temp_hevc\!newname!"
                        powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; function Get-End([string]$p) { $max=[double]::NegativeInfinity; foreach($s in 'v','a') { $lines=& ffprobe -v error -select_streams $s -show_entries packet=pts_time,duration_time -of csv=p=0 -i $p 2>$null; foreach($line in $lines) { $f=$line -split ','; [double]$pts=0; [double]$dur=0; $culture=[Globalization.CultureInfo]::InvariantCulture; $hasPts=[double]::TryParse($f[0],[Globalization.NumberStyles]::Float,$culture,[ref]$pts); $hasDuration=[double]::TryParse($f[1],[Globalization.NumberStyles]::Float,$culture,[ref]$dur); if($f.Count -ge 2 -and $hasPts -and $hasDuration) { $max=[Math]::Max($max,$pts+$dur) } } }; if([double]::IsNegativeInfinity($max)) { throw 'No video or audio packet timestamps found' }; return $max }; $sourceEnd=Get-End $env:MEDIA_SOURCE; $outputEnd=Get-End $env:MEDIA_OUTPUT; $difference=[Math]::Abs($sourceEnd-$outputEnd); Write-Output ('packet-end source={0:F3}s output={1:F3}s difference={2:F3}s' -f $sourceEnd,$outputEnd,$difference); exit [int]($difference -gt 0.5)" >> "%logfile%" 2>&1
                        if !errorlevel! equ 0 (
                            set "skip_encode=1"
                            >"temp_hevc\!newname!.complete" echo complete
                            echo Existing temp_hevc\!newname! passed decode and duration validation, skipping re-encoding >> "%logfile%"
                        ) else (
                            set "skip_encode=0"
                            del "temp_hevc\!newname!.complete" 2>nul
                            echo Existing temp_hevc\!newname! failed packet-end validation, re-encoding >> "%logfile%"
                        )
                    )
                )
            )
        )
        for /F "usebackq tokens=*" %%d in (`ffprobe -v error -select_streams v -show_entries format_tags^=title -of default^=noprint_wrappers^=1:nokey^=1 "!orig!!ext!" 2^>nul`) do (
            set current_meta_title="%%d"
            echo !current_meta_title! | findstr /i "GalaxyTV" >nul && set "meta_title=-metadata title="!current_meta_title:x264=x265!" "
        )
        if !skip_encode! equ 0 (
            if exist "!orig!.srt" (
                echo Encoding !orig!!ext! and muxing !orig!.srt to temp_hevc\!newname! >> "%logfile%"
                ffmpeg -i "!orig!!ext!" -i "!orig!.srt" -map 0 -map 1 -map_chapters 0 -map_metadata 0 !video_args! !audio_args! !sub_args! -c:t copy -c:d copy -movflags +faststart -metadata:s:s:0 language=eng !meta_title!!meta_comments! "temp_hevc\!newname!" -y
                
                if !errorlevel! neq 0 (
                    echo ERROR encoding !orig!!ext! and muxing !orig!.srt >> "%logfile%"
                    set "error_occurred=1"
                ) else (
                    >"temp_hevc\!newname!.complete" echo complete
                    echo Successfully encoded and muxed !orig!!ext! and !orig!.srt to !newname! >> "%logfile%"
                ) 
            ) else (
                echo Encoding !orig!!ext! to temp_hevc\!newname! >> "%logfile%"
                ffmpeg -i "!orig!!ext!" -map 0 -map_chapters 0 -map_metadata 0 !video_args! !audio_args! !sub_args! -c:t copy -c:d copy -movflags +faststart !meta_title!!meta_comments! "temp_hevc\!newname!" -y

                if !errorlevel! neq 0 (
                    echo ERROR encoding !orig!!ext! >> "%logfile%"
                    set "error_occurred=1"
                ) else (
                    >"temp_hevc\!newname!.complete" echo complete
                    echo Successfully encoded !orig!!ext! to !newname! >> "%logfile%"
                )
            )
        )
    )
)

REM If no errors, proceed to replace
if %error_occurred%==0 (
    REM Loop 2: Delete originals and move new ones
    for %%f in (*.avi *.mkv *.mp4) do (
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
            set "newname=!newname:FLAC=OPUS!"
            set "newname=!newname:flac=opus!"
            set "newname=!newname:DDP=OPUS!"
            set "newname=!newname:ddp=opus!"
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
                del "temp_hevc\!newname!.complete" 2>nul
                echo Replaced !orig!!ext! with !newname! >> "%logfile%"
            )
        )
    )
    rmdir temp_hevc
    echo All done! Check %logfile% for details.
) else (
    echo Errors occurred. Check outputs in temp_hevc and %logfile%.
    REM Keep temp_hevc for manual inspection
)
echo Ending HEVC re-encoding at %date% %time% >> "%logfile%"
echo Done. Log saved to %logfile%.
exit /b %error_occurred%