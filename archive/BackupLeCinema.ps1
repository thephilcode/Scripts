param (
    [string]$Source = "D:\Le Cinema",
    [string]$Dest1 = "E:\Le Cinema",  # For A–M
    [string]$Dest2 = "F:\Le Cinema",  # For N–Z
    [string]$CatalogFile = "catalog.csv"
)

$files = Get-ChildItem -Path $Source -Recurse -File

foreach ($file in $files) {
    # Get the first letter of the filename (ignoring case)
    $firstLetter = $file.Name.Substring(0,1).ToUpper()

    # Decide which drive it belongs to
    if ($firstLetter -ge "A" -and $firstLetter -le "M") {
        $destRoot = $Dest1
    } else {
        $destRoot = $Dest2
    }

    # Construct the destination path
    $relativePath = $file.FullName.Substring($Source.Length)
    $destPath = Join-Path $destRoot $relativePath

    # Ensure destination folder exists
    $destDir = Split-Path $destPath -Parent
    if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }

    # Copy only if new or changed
    if (!(Test-Path $destPath) -or ($file.LastWriteTime -gt (Get-Item $destPath).LastWriteTime)) {
        Copy-Item $file.FullName -Destination $destPath -Force
        Write-Host "Copied: $($file.Name)"
    }
}

Write-Host "✅ Split backup complete!"
