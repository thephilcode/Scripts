# Save as: Build-Catalog.ps1
param (
    [string]$SourcePath = "D:\Le Cinema",
    [string]$CatalogFile = "catalog.csv",
    [string]$DriveName = "Laptop"
)

$files = Get-ChildItem -Path $SourcePath -Recurse -File | Select-Object Name, FullName, Length, LastWriteTime

# Add Drive column
$files | ForEach-Object {
    [PSCustomObject]@{
        FileName      = $_.Name
        FullPath      = $_.FullName
        SizeBytes     = $_.Length
        ModifiedDate  = $_.LastWriteTime
        Drive         = $DriveName
    }
} | Export-Csv -Path $CatalogFile -NoTypeInformation -Append
