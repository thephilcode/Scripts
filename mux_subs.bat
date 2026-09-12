@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: v3.1 - 2026-06-30
:: This version adds handling for subtitle files with names equivalent to those of the matching video file plus '.en' like filename.en.subext

mkdir Muxed 2>nul
set error_occurred=0
set "logfile=mux_log.txt"
set match_found=0

echo Starting muxing at %date% %time% > "%logfile%"
:: Loop through all .mp4, .mkv and .webm files in the current folder
for %%f in (*.mp4 *.mkv *.webm) do (
    set "filename=%%~nf"
    set "ext=%%~xf"
    set "video=!filename!!ext!"
    
    :: Check if corresponding subtitle file exists
    for %%s in (*.srt *.vtt *.ass) do (
        set "subtitle=%%s"
        set "subext=%%~xs"
        if "!subtitle!" == "!filename!!subext!" (
            set match_found=1
        ) else if "!subtitle!" == "!filename!.en!subext!" (
            set match_found=1
        )

        if !match_found! equ 1 (
            echo Found matching subtitle for !video!: !subtitle! >> "%logfile%"
            echo Muxing video and subtitles... >> "%logfile%"
            set match_found=0

             if "!ext!" == ".mkv" (
                if "!subext!" == ".ass" (
                    ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0:v? -map 0:a? -map 0:s? -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec copy -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!video!"
                ) else (
                    ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0:v? -map 0:a? -map 0:s? -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec subrip -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!video!"
                )
            ) else if "!ext!" == ".mp4" (
                ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec mov_text -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!video!"
            ) else if "!ext!" == ".webm" (
                ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec webvtt -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!video!"
            ) else (
                ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec copy -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!video!"
            )
            :mux_check
            :: Checking if muxing was successful
            if !errorlevel! neq 0 (
                echo ERROR muxing !video! and !subtitle! >> "%logfile%"
                set /a error_occurred+=1
            ) else (
                echo Successfully muxed !video! and !subtitle! >> "%logfile%"
            )
        )
    )
)

if %error_occurred%==0 (
    for %%f in (*.mp4 *.mkv *.webm) do (
        set "file=%%f"
        set "fileext=%%~xf"
        set "sub="
        
        for %%s in (*.ass *.srt *.vtt) do (
            set "sub=%%s"
            set "subname=%%~ns"
            :: Check again if subtitle file exists, delete if it does
            if exist "Muxed\!subname!!fileext!" (
                echo Deleting subtitle file: !sub! >> "%logfile%"
                del "!sub!"
            ) else if exist "Muxed\!subname:.en=!!fileext!" (
                echo Deleting subtitle file: !sub! >> "%logfile%"
                del "!sub!"
            )
        )
        :: Check if output file exists; if it does, replace original with output
        if exist "Muxed\!file!" (
            echo Deleting original video: !file! >> "%logfile%"
            del "!file!"
            echo Moving !file! to parent folder >> "%logfile%"
            move "Muxed\!file!" ./
        )
    )
    REM Keep Muxed for manual inspection
) else (
    echo Some errors occured during muxing. Manually inspect files in 'Muxed' folder and the log file: %logfile%
    goto :end
)

echo To proceed with deleting Muxed folder and its contents, if any, press any key. Otherwise, check the contents of the folder first or close the terminal by clickiing the ✕ next to the tab name 
pause
echo Deleting Muxed folder >> "%logfile%"
rmdir Muxed
:end
exit