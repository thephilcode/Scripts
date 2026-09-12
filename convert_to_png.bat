@echo off
REM Check if ImageMagick's 'magick' command is available
where magick >nul 2>nul
IF ERRORLEVEL 1 (
    echo ImageMagick not found or not in PATH. Please install it from https://imagemagick.org
    pause
    exit /b
)

REM Make output directory
mkdir converted_pngs 2>nul

REM Loop through supported file types
for %%F in (*.jpg *.jpeg *.bmp *.gif *.tiff *.webp) do (
    echo Converting %%F...
    magick "%%F" "converted_pngs\%%~nF.png"
)

echo All conversions completed.
pause
