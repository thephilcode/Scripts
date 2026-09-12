@echo off
set "SRC=D:\Le Cinema"
set "DEST1=E:\Le Cinema"
set "DEST2=F:\Le Cinema"
set "LOGFILE=D:backup_log.txt"

for /r "%SRC%" %%F in (*) do (
    set "name=%%~nF"
    setlocal enabledelayedexpansion
    set "first=!name:~0,1!"
    for %%A in (A B C D E F G H I J K L M) do (
        if /I "!first!"=="%%A" (
            set "dest=%DEST1%"
            goto :copy
        )
    )
    set "dest=%DEST2%"
:copy
    robocopy "!SRC!" "!dest!" /LEV:1 /J /XD /XO /XX /IT /IM /X /V /IF "%%F" /R:2 /W:1 /MT:8 /TEE /LOG:"!LOGFILE!"
    endlocal
)
echo Split backup done!
pause
