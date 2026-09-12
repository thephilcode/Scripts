@echo off
setlocal enabledelayedexpansion

:: Unpacks all immediate subfolders by moving their file contents to the script's directory
:: and then removes the now-empty subfolders. Handles files with spaces; skips sub-subfolders

:: Log file
set LOGFILE=unpack_log.txt
echo Unpack started at %date% %time% > "%LOGFILE%"
echo This script moves the files and folders inside subfolders in the parent directory into the parent directory.
echo If no errors are encountered while moving, a subfolder is deleted after it has been unpacked.
echo The output is logged to the %LOGFILE% in the parent directory

set /a total_moved=0

for /d %%d in (*) do (
    if exist "%%d\*" (
        echo Processing folder: %%d >> "%LOGFILE%"
        move "%%d\*.*" . >> "%LOGFILE%" 2>&1
        if !errorlevel! equ 0 (
            echo Removing folder: %%d
            rmdir "%%d" >nul 2>&1
        ) else (
            echo Error: Failed to move files from %%d >> "%LOGFILE%"
        )
        for %%f in ("%%d\*.*") do set /a total_moved+=1
        echo >> "%LOGFILE%"
    )
)

echo Unpack completed. Total files moved: %total_moved% >> "%LOGFIFLE%"
echo Check %LOGFILE% for details
pause