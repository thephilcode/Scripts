@echo off
setlocal enabledelayedexpansion

set "logfile=replacement_log.txt"
echo Starting subtitle replacement at %date% %time% > "%logfile%"
if not exist "temp\" (
    mkdir "temp"
    echo Created temp folder >> "%logfile%"
) else (
    echo temp already exists, skipping creation >> "%logfile%"
)

set /a error_occured=0

for %%F in (*.mkv *.mp4) do (
    set "matching_sub=%%~F.srt"
	if exist !matching_sub! (
        echo Replacing HdmvSub subtitle in %%F with subrip subtitle !matching_sub! in temp\%%F >> "%logfile%"
        echo Replacing HdmvSub subtitle in %%F with subrip subtitle !matching_sub! in temp\%%F
        ffmpeg -i "%%F" -i "!matching_sub!" -map 0:v? -map 0:a? -map 1:s -map_metadata 0 -map_chapters 0 -c copy "temp\%%F"
        if !error_level! equ 0 (
            echo Successfully created output file temp\%%F >> "%logfile%"
        ) else (
            set /a error_occured+=1
            echo Error creating output file temp\%%F >> "%logfile%"
        )
    )
)

REM If no errors, proceed to replace
if %error_occurred%==0 (
    REM Loop 2: Delete originals and move new ones
    for %%F in (*.mkv *.mp4) do (
        if exist "temp_hevc\%%F" (
            echo Deleting original file: %%F
            del "%%F"
            if exist "%%~nF.srt" (
                echo Deleting %%~nF.srt
                del "%%~nF.srt"
            )
            if exist "%%~nF.sup" (
                echo Deleting %%~nF.sup
                del "%%~nF.sup"
            )
            if !errorlevel! equ 0 (
                move "temp\%%F" ./
                echo Replaced %%F >> "%logfile%"
            ) else (
                echo Error deleting original files >> "%logfile%"
                echo Error deleting original files
            )
        )
    )
    rmdir temp
    echo All done! Check %logfile% for details.
) else (
    echo Errors occurred—check outputs in temp_hevc and %logfile%.
    REM Keep temp for manual inspection
)
echo Done. Log saved to %logfile%.
pause

pause
