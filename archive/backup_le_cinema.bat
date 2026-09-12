@echo off
setlocal enabledelayedexpansion
title Le Cinema - Smart Split Backup (Full Structure)

set "SRC=D:\Le Cinema"
set "DEST_AM=E:\Le Cinema"
set "DEST_NZ=F:\Le Cinema"

echo.
echo Starting SMART SPLIT BACKUP of "%SRC%"
echo A-M → %DEST_AM%
echo N-Z → %DEST_NZ%
echo.
echo This keeps ALL folders and only copies newer/missing files
echo.

rem Create root backup folders if they don't exist
if not exist "%DEST_AM%" md "%DEST_AM%"
if not exist "%DEST_NZ%" md "%DEST_NZ%"

rem Use robocopy — way faster, safer and more reliable than xcopy
for /f "delims=" %%F in ('dir "%SRC%" /b /s /a-d ^| findstr /i "\.mp4$ \.mkv$ \.avi$ \.mov$ \.m4v$"') do (
    set "fullpath=%%F"
    set "filename=%%~nF"
    set "first=!filename:~0,1!"
    rem First letter of filename (not folder!)

    set "target=%DEST_AM%"
    for %%A in (N O P Q R S T U V W X Y Z n o p q r s t u v w x y z) do (
        if /i "!first!"=="%%A" set "target=%DEST_NZ%"
    )

    rem Calculate relative path so folder structure is preserved
    set "relpath=!fullpath:%SRC%=!"

    robocopy "%SRC%" "!target!" "!relpath!" /COPY:DAT /DCOPY:DAT /NP /NS /NC /NFL /R:2 /W:2 /MT:32 /LOG+:"%~dp0LeCinema_backup_log.txt" /TEE
)

echo.
echo Split backup with full folder structure COMPLETED!
echo Log saved to: %~dp0LeCinema_backup_log.txt
pause