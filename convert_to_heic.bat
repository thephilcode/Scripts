@echo off
setlocal

if not exist "heic_output" mkdir "heic_output"

echo Starting fast parallel HEIC conversion...
echo.

> "heic_output\_worker.sh" (
echo shopt -s nullglob nocaseglob
echo files=(*.jpg *.jpeg *.png *.tif *.tiff *.bmp^)
echo.
echo if [ ${#files[@]} -eq 0 ]; then
echo   echo "No supported images found."
echo   exit 0
echo fi
echo.
echo export MAGICK_THREAD_LIMIT=1
echo.
echo convert_one(^) {
echo   f="$1"
echo   base="${f%%.*}"
echo   ext="${f##*.}"
echo   out="heic_output/${base}.heic"
echo.
echo   if [[ "${ext,,}" == "jpg" ^|^| "${ext,,}" == "jpeg" ]]; then
echo     magick "$f" -auto-orient -sampling-factor 4:2:0 -quality 52 "$out"
echo   else
echo     magick "$f" -auto-orient -sampling-factor 4:2:0 -quality 75 "$out"
echo   fi
echo.
echo   if [ -f "$out" ]; then
echo     orig_size=$(stat -c%%s "$f"^)
echo     new_size=$(stat -c%%s "$out"^)
echo     pct=$(( new_size * 100 / orig_size ^)^)
echo     diff=$(( pct - 100 ^)^)
echo     if [ $diff -le 0 ]; then
echo       neg_diff=$(( -diff ^)^)
echo       printf "[OK] %%s -> %%d%%%% of original (%%d%%%% smaller)\n" "$f" "$pct" "$neg_diff"
echo     else
echo       printf "[LARGER] %%s -> %%d%%%% of original (+%%d%%%% larger)\n" "$f" "$pct" "$diff"
echo     fi
echo   else
echo     printf "[ERR] Failed to convert %%s\n" "$f"
echo   fi
echo }
echo export -f convert_one
echo cores=$(nproc^)
echo echo "Using $cores parallel workers..."
echo printf "%%s\0" "${files[@]}" ^| xargs -0 -n 1 -P "$cores" bash -c 'convert_one "$@"' _
)

wsl bash -c "tr -d '\r' < heic_output/_worker.sh | bash"
del "heic_output\_worker.sh" 2>nul

echo.
echo Syncing file timestamps...
powershell -NoProfile -Command ^
  "$originals = Get-ChildItem -File | Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|tif|tiff|bmp)$' };" ^
  "foreach ($orig in $originals) {" ^
  "  $heic = Join-Path 'heic_output' ($orig.BaseName + '.heic');" ^
  "  if (Test-Path -LiteralPath $heic) {" ^
  "    $item = Get-Item -LiteralPath $heic;" ^
  "    $item.CreationTime = $orig.CreationTime;" ^
  "    $item.LastWriteTime = $orig.LastWriteTime;" ^
  "    $item.LastAccessTime = $orig.LastAccessTime;" ^
  "  }" ^
  "}"

echo.
echo All conversions complete! Files saved in "heic_output".
pause
