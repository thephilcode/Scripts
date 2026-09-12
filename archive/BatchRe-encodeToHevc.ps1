# reencode_hevc.ps1
$logfile = "reencode_log.txt"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"Starting HEVC re-encoding at $timestamp" | Out-File $logfile -Encoding utf8
New-Item -ItemType Directory -Path "temp_hevc" -Force | Out-Null
$errorOccurred = $false

# Loop 1: Encode all to temp, skipping files with x265/h265
$files = Get-ChildItem -Include *.mp4,*.mkv -Recurse:$false
foreach ($file in $files) {
    $origName = $file.BaseName
    $ext = $file.Extension
    if ($origName -imatch "x265|h265") {
        "Skipping $origName$ext - already processed" | Out-File $logfile -Append
    } else {
        $newName = $origName -replace "x264", "x265" -replace "h264", "h265"
        $newFile = "temp_hevc\$newName$ext"
        "Encoding $origName$ext to $newFile" | Out-File $logfile -Append
        & ffmpeg -i "$($file.FullName)" -sub_charenc UTF-8 -map 0 -map_chapters 0 -map_metadata 0 -c:v libx265 -preset medium -crf 28 -x265-params "bframes=4:rc-lookahead=40:ref=4" -c:a copy -c:s copy -movflags +faststart -metadata comment="Re-encoded by ScreenPhantom 📺👻" -metadata:s:v:0 comment="Re-encoded by ScreenPhantom 📺👻" "$newFile" -y
        if ($LASTEXITCODE -ne 0) {
            "ERROR encoding $origName$ext" | Out-File $logfile -Append
            $errorOccurred = $true
        } else {
            "Successfully encoded $origName$ext to $newName$ext" | Out-File $logfile -Append
        }
    }
}

# If no errors, proceed to replace
if (-not $errorOccurred) {
    foreach ($file in $files) {
        $origName = $file.BaseName
        $ext = $file.Extension
        if ($origName -imatch "x265|h265") {
            "Skipping replacement for $origName$ext" | Out-File $logfile -Append
        } else {
            $newName = $origName -replace "x264", "x265" -replace "h264", "h265"
            $newFile = "temp_hevc\$newName$ext"
            if (Test-Path $newFile) {
                Remove-Item $file.FullName -Force
                Move-Item $newFile "$newName$ext" -Force
                "Replaced $origName$ext with $newName$ext" | Out-File $logfile -Append
            }
        }
    }
    Remove-Item -Path "temp_hevc" -Recurse -Force
    "All done! Check $logfile for details." | Out-File $logfile -Append
} else {
    "Errors occurred—check outputs in temp_hevc and $logfile." | Out-File $logfile -Append
}
Write-Host "Done. Log saved to $logfile."
pause