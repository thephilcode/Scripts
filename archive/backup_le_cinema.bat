@echo off
set "SOURCE=D:\Le Cinema"
set "DEST=E:\Le Cinema"
set "CATALOG=catalog.csv"
set "DRIVE=ExternalDrive"

echo Starting backup...
robocopy "%SOURCE%" "%DEST%" /E /XO /XN /R:1 /W:1 /MT:8 /LOG:backup.log /TEE

echo Updating catalog...
(for /r "%DEST%" %%F in (*) do (
    echo %%~nxF,%%~fF,%%~zF,%DATE% %TIME%,%DRIVE%
)) >> "%CATALOG%"

echo Done!
pause
