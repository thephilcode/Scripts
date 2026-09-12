@echo off
set "Source=D:\Le Cinema"
set "Catalog=catalog.csv"
set "Drive=Laptop"

(for /r "%Source%" %%F in (*) do (
    echo %%~nxF,%%~fF,%%~zF,%DATE% %TIME%,%Drive%
)) >> "%Catalog%"
