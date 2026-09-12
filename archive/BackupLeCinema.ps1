# Save as Backup-LeCinema.ps1
param (
    [string]$Source = "D:\Le Cinema",
    [string]$Dest = "E:\Le Cinema",
    [string]$CatalogFile = "catalog.csv",
    [string]$DriveName = "ExternalDrive"
)

Write-Host "🔍 Checking available space..."
$freeBytes = (Get-PSDrive -Name ($Dest.Substring(0,1))).Free
$requiredBytes = (Get-ChildItem -Recurse $Source | Measure-Object Length -Sum).Sum

if ($freeBytes -lt $requiredBytes) {
    Write-Host "⚠️ Not enough space. Required: $([math]::Round($requiredBytes/1MB,2)) MB, Free: $([math]::Round($freeBytes/1MB,2)) MB"
    exit
}

Write-Host "📂 Starting backup..."
robocopy $Source $Dest /E /XO /XN /R:1 /W:1 /MT:8 /LOG:backup.log /TEE

Write-Host "🗂 Updating catalog..."
$files = Get-ChildItem -Path $Dest -Recurse -File | Select-Object FullName, Length, LastWriteTime
$files | ForEach-Object {
    [PSCustomObject]@{
        FileName      = $_.Name
        FullPath      = $_.FullName
        SizeBytes     = $_.Length
        ModifiedDate  = $_.LastWriteTime
        Drive         = $DriveName
    }
} | Export-Csv -Path $CatalogFile -NoTypeInformation -Append

Write-Host "✅ Backup + Catalog complete!"
