@echo off
setlocal enabledelayedexpansion

set "logfile=rename_log.txt"
set error_occured=0
set "orig=%~1"
set "repl=%~2"

if "%orig%"=="" (
    echo     ERROR: No string to be replaced was supplied.
    echo     To replace strings in the names of video files, open the terminal in the folder containing the files and run:
    echo     %~nx0 "old_string" "replacement_string"
    pause & exit /b 1
)

if "%repl%"=="" (
    echo     ERROR: No replacement string was supplied.
    echo     To replace strings in the names of video files, open the terminal in the folder containing the files and run:
    echo     %~nx0 "old_string" "replacement_string"
    pause & exit /b 1
)

for %%f in (*.mp4 *.mkv) do (
    set "old_fn=%%f"
    set "replmnt=old_fn"
    set "replmnt=!replmnt!:!orig!="
    set "replmnt=!replmnt!!repl!"
    set "new_fn=%!replmnt!%"
    echo Replacemnt: !replmnt!
    echo Renaming %%f to !new_fn! >> "%logfile%"
    echo Renaming %%f to !new_fn!
    ren "!old_fn!" "!new_fn!"
    if !errorlevel! neq 0 (
        set error_occured=1
        echo Error renaming %%f to !newfn! >> "%logfile%"
    ) else (
        echo Successfully renamed %%f to !new_fn!
    )
)
if !error_occured! equ 1 (
    echo Some errors occured while renaming. Inspect the outputs and the logs in %logfile%.
) else (
    echo All replacements done! Check %logfile% for details.
)
pause
