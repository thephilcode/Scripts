@echo off
setlocal enabledelayedexpansion

set "logfile=duplicate_deletion_log.txt"

for /f "usebackq tokens=1 delims=" %%f in ("duplicates.txt") do (
    echo Deleting %%f >> "%logfile%"
    del "%%f"
)
pause