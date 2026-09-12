@echo off
setlocal enabledelayedexpansion
echo =========================================
echo             UPDATING TOOLS
echo =========================================

set tools[0]=Gyan.FFmpeg
set tools[1]=Starship.Starship
set tools[2]=ajeetdsouza.zoxide
set tools[3]=junegunn.fzf
set tools[4]=chrisant996.Clink
set tools[5]=7zip.7zip
set tools[6]=Git.Git
set tools[7]=GitHub.cli

echo.
echo Updating yt-dlp via pip...
python -m pip install -U yt-dlp[default]

for /L %%i in (0,1,7) do (
    set "tool=!tools[%%i]!"
    for /F "tokens=2 delims=." %%A in ("!tool!") do set "name=%%A"
    for /F "usebackq delims=" %%B in (`powershell -NoProfile -Command "'!name!'.ToLower()"`) do set "name=%%B"
    echo.
    echo Updating !name! via winget...
    winget upgrade "!tool!" --silent --uninstall-previous --accept-package-agreements --accept-source-agreements
)
endlocal

echo.
echo =========================================
echo             UPDATES COMPLETE!
echo =========================================
echo.
pause
