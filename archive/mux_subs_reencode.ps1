param (
    [string]$VideoFile
)

# 1.0
# mux_subs_reencode.ps1

# Configuration
$SubsDir = "Subs"
$HevcPreset = "medium"
$HevcCrf = 23

# Check if video file is provided and exists
if (-not $VideoFile) {
    Write-Error "No video file provided! Run with: .\mux_subs_reencode.ps1 `"your_video.mkv`""
    pause
    exit 1
}
if (-not (Test-Path $VideoFile)) {
    Write-Error "Video file '$VideoFile' not found! Make sure to run from the parent folder."
    pause
    exit 1
}

# Derive output filename with x264 -> x265 replacement (case-insensitive)
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($VideoFile)
$Ext = [System.IO.Path]::GetExtension($VideoFile)
$LowerBase = $BaseName.ToLower()
if ($LowerBase -match "x264") {
    $OutputBase = $BaseName -creplace "(?i)x264", "x265"  # Case-insensitive replace first match
} else {
    $OutputBase = "$BaseName-x265"
}
$OutputFile = "$OutputBase$Ext"
Write-Host "Output will be: $OutputFile" -ForegroundColor Yellow

# Check if subtitle file with same name exists
$MainSub = "$BaseName.srt"
if (-not (Test-Path $MainSub)) {
    Write-Warning "No subtitle file '$MainSub' found in parent folder. Proceeding without default subtitle."
    $MainSub = $null
}

# Check if Subs folder exists
if (-not (Test-Path $SubsDir)) {
    Write-Error "Subtitles folder '$SubsDir' not found!"
    pause
    exit 1
}

# Initialize FFmpeg command parts
$Inputs = "-i `"$VideoFile`""
$Maps = "-map 0"
$Codecs = "-c:v libx265 -preset $HevcPreset -crf $HevcCrf -c:a copy -c:s copy"
$Dispositions = @()
$Metadata = @()
$SubCount = 1
$DefaultSet = $false

# Add main subtitle file (if exists) as first input and set as default
if ($MainSub) {
    $Inputs += " -i `"$MainSub`""
    $Maps += " -map 1"
    $Metadata += "-metadata:s:s:0 language=eng"
    $Dispositions += "-disposition:s:0 default"
    $DefaultSet = $true
    
    # Check for forced in main sub filename (case-insensitive)
    $MainName = [System.IO.Path]::GetFileNameWithoutExtension($MainSub)
    if ($MainName -match "(?i)forced") {
        $Dispositions += "-disposition:s:0 forced"
    }
}

# Process subtitle files in Subs folder (sorted alphabetically)
$SubFiles = Get-ChildItem -Path "$SubsDir\*.srt" | Sort-Object Name
foreach ($SubFile in $SubFiles) {
    $FileName = [System.IO.Path]::GetFileNameWithoutExtension($SubFile.Name)
    
    # Extract three-letter language code
    $Lang = if ($FileName.Length -ge 3 -and $FileName -notmatch '\.srt$') { 
        $FileName.Substring($FileName.Length - 3) 
    } else { 
        'und' 
    }
    
    # Check for forced (case-insensitive)
    $Disp = @()
    if ($FileName -match "(?i)forced") {
        $Disp += "forced"
    }
    
    $Inputs += " -i `"$($SubFile.FullName -replace '\\', '/')`""
    $Maps += " -map $SubCount"
    $Metadata += "-metadata:s:s:$SubCount language=$Lang"
    if ($Disp) { 
        $Dispositions += "-disposition:s:$SubCount $($Disp -join ' ')" 
    }
    $SubCount++
}

# Build full FFmpeg command
$FfmpegCmd = "ffmpeg $Inputs $Codecs $Maps $($Metadata -join ' ') $($Dispositions -join ' ') -map_metadata 0 -y `"$OutputFile`""

# Print the command
Write-Host "`nGenerated FFmpeg command (reencoding to HEVC):" -ForegroundColor Green
Write-Host $FfmpegCmd
Write-Host "`nCopy and paste the above command to run it after inspection/tweaks (e.g., change -crf 23 for quality/size)."
Read-Host "Press Enter to close"