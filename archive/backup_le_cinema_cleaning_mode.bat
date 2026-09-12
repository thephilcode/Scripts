@echo off
setlocal enabledelayedexpansion
title Le Cinema - FLAT Split Backup (temporary cleaning mode)

set "SRC=D:\Le Cinema"
set "DEST_AM=E:\Le Cinema"
set "DEST_NZ=F:\Le Cinema"

echo.
echo Starting FLAT split backup (no folders, just files)
echo A-M → %DEST_AM%
echo N-Z → %DEST_NZ%
echo.
echo Perfect for temporary use while you finish re-encoding and flattening
echo.

if not exist "%DEST_AM%" md "%DEST_AM%"
if not exist "%DEST_NZ%" md "%DEST_NZ%"

echo Flattening and copying — this may take a while...
echo.

(for /r "%SRC%" %%F in (*.mp4 *.mkv *.avi *.mov *.m4v) do (
    set "filename=%%~nxF"
    set "first=!filename:~0,1!"

    set "target=%DEST_AM%"
    for %%A in (N O P Q R S T U V W X Y Z n o p q r s t u v w x y z) do (
        if /i "!first!"=="%%A" set "target=%DEST_NZ%"
    )

    echo Copying "!filename!" → !target!
    copy "%%F" "!target!\!filename!" /Y >nul
)) 2>nul

echo.
echo Flat split backup finished!
echo Check %DEST_AM% and %DEST_NZ%
pause