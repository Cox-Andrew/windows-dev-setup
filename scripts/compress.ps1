<#
.SYNOPSIS
    Compresses video files using FFmpeg (libx265) with a quality preset.

.DESCRIPTION
    This script automates video compression using single-pass CRF encoding (H.265/HEVC).
    It provides consistent visual quality using low, medium, and high quality presets.

.PARAMETER Path
    The path to the source video file.

.PARAMETER Quality
    Compression quality preset: 'low', 'medium', or 'high' (default).

.PARAMETER Low
    Shortcut switch for -Quality low.

.PARAMETER Medium
    Shortcut switch for -Quality medium.

.PARAMETER High
    Shortcut switch for -Quality high.

.PARAMETER Mute
    If present, the audio stream will be stripped.

.PARAMETER Open
    If present, opens the compressed video in Microsoft Edge after encoding.

.PARAMETER Verbose
    If present, displays FFmpeg stream info, encoding progress, and detailed logs.

.PARAMETER Help
    Displays this help documentation.

.EXAMPLE
    .\compress.ps1 -Path "input.mp4"

.EXAMPLE
    .\compress.ps1 -Path "input.mp4" -Quality medium

.EXAMPLE
    .\compress.ps1 -Path "input.mp4" -Low -Mute

.EXAMPLE
    .\compress.ps1 -Path "input.mp4" -Open

.EXAMPLE
    .\compress.ps1 -help
#>

[CmdletBinding(DefaultParameterSetName = "Compress")]
param (
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Compress")]
    [string]$Path,

    [Parameter(Position = 1, ParameterSetName = "Compress")]
    [ValidateSet("low", "medium", "high", IgnoreCase = $true)]
    [string]$Quality = "high",

    [Parameter(ParameterSetName = "Compress")]
    [switch]$Low,

    [Parameter(ParameterSetName = "Compress")]
    [switch]$Medium,

    [Parameter(ParameterSetName = "Compress")]
    [switch]$High,

    [Parameter(ParameterSetName = "Compress")]
    [switch]$Mute,

    [Parameter(ParameterSetName = "Compress")]
    [switch]$Open,

    [Parameter(ParameterSetName = "Help")]
    [Alias("h", "?")]
    [switch]$Help
)

# --- 1. Help & Validation ---
if ($Help -or $Path -eq "--help" -or $Path -eq "-h" -or $Path -eq "-help") {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

# Check for FFmpeg installation
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "Error: FFmpeg is not installed or not found in your PATH." -ForegroundColor Red
    Write-Host "You can install FFmpeg via winget using:" -ForegroundColor Yellow
    Write-Host "    winget install Gyan.FFmpeg`n" -ForegroundColor Cyan

    $canPrompt = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
    if ($canPrompt) {
        $install = Read-Host "Would you like to install FFmpeg now using winget? (Y/N)"
        if ($install -match '^[Yy]') {
            Write-Host "Running: winget install Gyan.FFmpeg" -ForegroundColor Cyan
            winget install Gyan.FFmpeg
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
                Write-Host "FFmpeg was installed, but you may need to restart your terminal for PATH changes to take effect." -ForegroundColor Yellow
                exit 1
            }
            Write-Host "FFmpeg installed successfully!`n" -ForegroundColor Green
        } else {
            exit 1
        }
    } else {
        exit 1
    }
}

if (-not (Test-Path $Path)) {
    Write-Host "Error: File '$Path' not found." -ForegroundColor Red
    exit 1
}

# --- 2. Resolve Quality & Settings ---
if ($Low) { $Quality = "low" }
elseif ($Medium) { $Quality = "medium" }
elseif ($High) { $Quality = "high" }

switch ($Quality.ToLower()) {
    "low" {
        $crf = 30
        $audioBitrate = "96k"
    }
    "medium" {
        $crf = 26
        $audioBitrate = "128k"
    }
    default {
        # High (Default)
        $crf = 22
        $audioBitrate = "192k"
    }
}

# Check if input video contains an audio stream and get duration
$totalDuration = 0.0
$hasAudio = $false
try {
    $probeDuration = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$Path" 2>$null
    if ($probeDuration -as [double]) {
        $totalDuration = [double]$probeDuration
    }
    $probeAudio = ffprobe -v error -select_streams a -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 "$Path" 2>$null
    if ($probeAudio -match "audio") {
        $hasAudio = $true
    }
} catch {
    $hasAudio = $false
}

if ($hasAudio -and (-not $Mute)) {
    $audioArgs = @("-c:a", "aac", "-b:a", $audioBitrate)
} else {
    $audioArgs = @("-an")
}

$outputFile = [System.IO.Path]::GetFileNameWithoutExtension($Path) + ".compressed.mp4"

# --- 3. Execution ---
$isVerbose = $VerbosePreference -ne 'SilentlyContinue' -or $PSBoundParameters.ContainsKey('Verbose')
$verbosityArgs = if ($isVerbose) {
    Write-Verbose "Verbose output enabled. Displaying full FFmpeg logs."
    @("-progress", "pipe:1")
} else {
    @("-hide_banner", "-loglevel", "error", "-progress", "pipe:1")
}

Write-Host "`nCompressing '$Path' (Quality: $Quality, CRF: $crf)..." -ForegroundColor Cyan

$ffmpegArgs = $verbosityArgs + @(
    "-y",
    "-i", $Path,
    "-c:v", "libx265",
    "-crf", $crf,
    "-preset", "medium",
    "-tag:v", "hvc1"
) + $audioArgs + @($outputFile)

$fileName = [System.IO.Path]::GetFileName($Path)
$currentSpeed = ""
$currentFps = ""

& ffmpeg @ffmpegArgs | ForEach-Object {
    $line = $_
    if ($line -match '^speed=\s*(\S+)') {
        $currentSpeed = $Matches[1]
    }
    elseif ($line -match '^fps=\s*(\S+)') {
        $currentFps = $Matches[1]
    }
    elseif ($line -match '^out_time_us=(\d+)') {
        if ($totalDuration -gt 0) {
            $currentTimeSec = [double]$Matches[1] / 1000000.0
            $percent = [math]::Min(99, [math]::Max(0, [math]::Round(($currentTimeSec / $totalDuration) * 100)))
            $statusMsg = "$percent% complete"
            if ($currentSpeed -and $currentSpeed -ne 'N/A') { $statusMsg += " | Speed: $currentSpeed" }
            if ($currentFps -and $currentFps -ne '0.00' -and $currentFps -ne 'N/A') { $statusMsg += " | FPS: $currentFps" }

            Write-Progress -Activity "Compressing $fileName" `
                -Status $statusMsg `
                -PercentComplete $percent
        }
    }
    elseif ($line -match '^out_time=(\S+)' -and $totalDuration -le 0) {
        $statusMsg = "Time: $($Matches[1])"
        if ($currentSpeed -and $currentSpeed -ne 'N/A') { $statusMsg += " | Speed: $currentSpeed" }
        if ($currentFps -and $currentFps -ne '0.00' -and $currentFps -ne 'N/A') { $statusMsg += " | FPS: $currentFps" }

        Write-Progress -Activity "Compressing $fileName" -Status $statusMsg
    }
    elseif ($line -match '^progress=end') {
        Write-Progress -Activity "Compressing $fileName" -Status "100% complete" -PercentComplete 100
    }
}
Write-Progress -Activity "Compressing $fileName" -Completed

$exitCode = $LASTEXITCODE

# --- 4. Final Report ---
if ($exitCode -eq 0) {
    $origSize = (Get-Item $Path).Length / 1MB
    $finalSize = (Get-Item $outputFile).Length / 1MB
    $savedPct = [math]::Round((1 - ($finalSize / $origSize)) * 100, 1)
    $resolvedPath = (Resolve-Path $outputFile).Path
    $fileUri = "file:///" + ($resolvedPath -replace '\\', '/')

    Write-Host "`nSuccess!" -ForegroundColor Green
    Write-Host "Output saved to : $outputFile"
    Write-Host "Original size   : $([math]::Round($origSize, 2)) MB"
    Write-Host "Compressed size : $([math]::Round($finalSize, 2)) MB ($savedPct% saved)"

    Write-Host "`nHint: Windows Media Player cannot play HEVC (H.265) without a paid extension." -ForegroundColor Yellow
    Write-Host "If playback fails, you can open the file in Microsoft Edge or VLC:" -ForegroundColor Yellow
    Write-Host "  Link   : $fileUri" -ForegroundColor Cyan
    Write-Host "  Command: Start-Process msedge `"$resolvedPath`"" -ForegroundColor Cyan

    if ($Open) {
        Start-Process msedge $resolvedPath
    }
} else {
    Write-Host "Error: FFmpeg compression failed." -ForegroundColor Red
    exit 1
}
