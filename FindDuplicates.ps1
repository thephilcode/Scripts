# Save as: Find-Duplicates.ps1
param (
    [string]$Folder1 = "F:\Le Cinema",
    [string]$Folder2 = "G:\Le Cinema",
    [string]$OutputFile = "duplicates.txt"
)

$files1 = Get-ChildItem -Path $Folder1 -Recurse -File | Select-Object Name, FullName
$files2 = Get-ChildItem -Path $Folder2 -Recurse -File | Select-Object Name, FullName

$dupFiles = Compare-Object -ReferenceObject $files1 -DifferenceObject $files2 -Property Name -IncludeEqual -ExcludeDifferent | Where-Object { $_.SideIndicator -eq "==" }

$dupFiles | ForEach-Object {
    "Duplicate File: $($_.Name)"
} | Out-File -FilePath $OutputFile

# Also check for duplicate folder names
$folders1 = Get-ChildItem -Path $Folder1 -Recurse -Directory | Select-Object Name, FullName
$folders2 = Get-ChildItem -Path $Folder2 -Recurse -Directory | Select-Object Name, FullName

$dupFolders = Compare-Object -ReferenceObject $folders1 -DifferenceObject $folders2 -Property Name -IncludeEqual -ExcludeDifferent | Where-Object { $_.SideIndicator -eq "==" }

$dupFolders | ForEach-Object {
    "Duplicate Folder: $($_.Name)"
} | Out-File -FilePath $OutputFile -Append
