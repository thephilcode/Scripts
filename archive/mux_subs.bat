@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: v3.0 - 2025-11-17
:: This version includes better error handling and compatibility checking.
:: More importantly, it accepts a wider variety of subtitle and video file types and re-encodes them as necessary to ensure compatibility in the output file.

mkdir Muxed 2>nul
set error_occurred=0
set "logfile=mux_log.txt"

echo Starting muxing at %date% %time% > "%logfile%"
:: Loop through all .mp4 or .mkv files in the current folder
for %%f in (*.mp4 *.mkv *.webm) do (
    set "filename=%%~nf"
    set "ext=%%~xf"
    set "video=%%f"
    set "output=!filename!!ext!"
    
    :: Check if corresponding subtitle file exists
    for %%s in (*.srt *.vtt *.ass) do (
        set "subtitle=%%s"
        set "subext=%%~xs"
        if "!subtitle!" == "!filename!!subext!" (
            echo Found matching subtitle for !video!: !subtitle! >> "%logfile%"
            echo Muxing video and subtitles... >> "%logfile%"

             if "!ext!" == ".mkv" (
                if "!subext!" == ".ass" (
                    ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0:v? -map 0:a? -map 0:s? -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec copy -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!output!"
                ) else (
                    ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0:v? -map 0:a? -map 0:s? -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec subrip -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!output!"
                )
            ) else if "!ext!" == ".mp4" (
                ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec mov_text -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!output!"
            ) else if "!ext!" == ".webm" (
                ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec webvtt -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!output!"
            ) else (
                ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -vcodec copy -acodec copy -scodec copy -metadata comment="Re-muxed by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "Muxed\!output!"
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