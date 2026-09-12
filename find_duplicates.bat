@echo off
set "Folder1=F:\Le Cinema"
set "Folder2=G:\Le Cinema"
set "Output=duplicates.txt"

del "%Output%" >nul 2>&1

for /r "%Folder1%" %%F in (*) do (
    if exist "%Folder2%\%%~nxF" echo Duplicate File: %%~nxF >> "%Output%"
)

for /d /r "%Folder1%" %%D in (*) do (
    if exist "%Folder2%\%%~nxD" echo Duplicate Folder: %%~nxD >> "%Output%"
)
