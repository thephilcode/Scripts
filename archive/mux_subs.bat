@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Loop through all .mp4 or .mkv files in the current folder
for %%f in (*.mp4 *.mkv) do (
    set "filename=%%~nf"
    set "ext=%%~xf"
    set "video=%%f"
    set "subtitle=!filename!.srt"
    set "output=!filename!_subtitled!ext!"
    
    :: Check if corresponding .srt file exists
    if exist "!subtitle!" (
        echo Found matching subtitle for !video!: !subtitle!
        echo Muxing video and subtitles...

        if "!ext!" == ".mkv" (
            ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -scodec srt -metadata comment="Edited by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "!output!"
        ) else if "!ext!" == ".mp4" (
            ffmpeg -i "!video!" -sub_charenc UTF-8 -i "!subtitle!" -map 0 -map 1 -map_chapters 0 -map_metadata 0 -c copy -scodec mov_text -metadata comment="Edited by ScreenPhantom 📺👻" -metadata:s:s:0 language=eng -disposition:s:0 default "!output!"
        )

    ) else (
        echo No matching subtitle found for !video!
    )

    :: Check if output file has been created
    if exist "!output!" (
        :: Delete original video and subtitle files
        echo Deleting original video: !video!
        del "!video!"
        echo Deleting subtitle file: !subtitle!
        del "!subtitle!"
        echo Renaming output file to !video!
        ren "!output!" "!video!"
    )
)

echo Done.
pause
