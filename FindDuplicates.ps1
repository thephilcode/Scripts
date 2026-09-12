param (
    [string]$Folder1 = "F:\Le Cinema",
    [string]$Folder2 = "G:\Le Cinema",
    [string]$OutputFile = "duplicates.txt"
)

# Get all files recursively from both folders
$files1 = Get-ChildItem -Path $Folder1 -Recurse -File
$files2 = Get-ChildItem -Path $Folder2 -Recurse -File

# Build relative paths like Series\Season\Episode
$rel1 = $files1 | ForEach-Object { $_.FullName.Substring($Folder1.Length+1) }
$rel2 = $files2 | ForEach-Object { $_.FullName.Substring($Folder2.Length+1) }

# Compare relative paths to find duplicates
$duplicates = $rel1 | Where-Object { $rel2 -contains $_ }

# Output duplicates
$duplicates | ForEach-Object {
    "Duplicate File: $_"
} | Out-File -FilePath $OutputFile

Write-Host "✅ Duplicate check complete. Results in $OutputFile"
