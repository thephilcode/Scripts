@echo off
set "Folder1=D:\Le Cinema"
set "Folder2=E:\Le Cinema"
set "Output=duplicates.txt"

del "%Output%" >nul 2>&1

for /r "%Folder1%" %%F in (*) do (
    set "Rel=%%F"
    setlocal enabledelayedexpansion
    set "Rel=!Rel:%Folder1%\=!"
    if exist "%Folder2%\!Rel!" echo %Folder2%\!Rel! >> "%Output%"
    endlocal
)
