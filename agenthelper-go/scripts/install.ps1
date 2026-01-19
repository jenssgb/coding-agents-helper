# AgentHelper Windows Installer
# Usage: irm https://github.com/USER/agenthelper/releases/latest/download/install.ps1 | iex

$ErrorActionPreference = "Stop"

# Configuration
$repo = "jschneider/agenthelper"
$installDir = "$env:LOCALAPPDATA\Programs\agenthelper"
$binName = "agenthelper.exe"

Write-Host ""
Write-Host "  AgentHelper Installer" -ForegroundColor Cyan
Write-Host "  =====================" -ForegroundColor Cyan
Write-Host ""

# Detect architecture
$arch = if ([Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64" -or $env:PROCESSOR_ARCHITEW6432 -eq "ARM64") {
        "arm64"
    } else {
        "amd64"
    }
} else {
    "386"
}

Write-Host "  Platform: Windows $arch" -ForegroundColor Gray

# Get latest release
Write-Host "  Fetching latest release..." -ForegroundColor Gray
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
    $version = $release.tag_name
    Write-Host "  Latest version: $version" -ForegroundColor Green
} catch {
    Write-Host "  Error: Could not fetch latest release" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}

# Find download URL
$assetName = "agenthelper-windows-$arch.exe"
$asset = $release.assets | Where-Object { $_.name -eq $assetName }

if (-not $asset) {
    # Try zip format
    $assetName = "agenthelper-$version-windows-$arch.zip"
    $asset = $release.assets | Where-Object { $_.name -eq $assetName }
}

if (-not $asset) {
    Write-Host "  Error: Could not find binary for Windows $arch" -ForegroundColor Red
    Write-Host "  Available assets:" -ForegroundColor Yellow
    $release.assets | ForEach-Object { Write-Host "    - $($_.name)" }
    exit 1
}

$downloadUrl = $asset.browser_download_url
Write-Host "  Downloading from: $downloadUrl" -ForegroundColor Gray

# Create install directory
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$downloadPath = Join-Path $env:TEMP $asset.name
$binPath = Join-Path $installDir $binName

# Download
Write-Host "  Downloading..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing
} catch {
    Write-Host "  Error: Download failed" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}

# Extract if zip
if ($asset.name -like "*.zip") {
    Write-Host "  Extracting..." -ForegroundColor Gray
    $extractPath = Join-Path $env:TEMP "agenthelper-extract"
    if (Test-Path $extractPath) {
        Remove-Item -Recurse -Force $extractPath
    }
    Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force

    # Find the exe
    $exe = Get-ChildItem -Path $extractPath -Filter "*.exe" -Recurse | Select-Object -First 1
    if ($exe) {
        Copy-Item -Path $exe.FullName -Destination $binPath -Force
    } else {
        Write-Host "  Error: Could not find executable in archive" -ForegroundColor Red
        exit 1
    }

    Remove-Item -Recurse -Force $extractPath
} else {
    # Direct exe download
    Copy-Item -Path $downloadPath -Destination $binPath -Force
}

Remove-Item -Force $downloadPath -ErrorAction SilentlyContinue

# Add to PATH if not already
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$installDir*") {
    Write-Host "  Adding to PATH..." -ForegroundColor Gray
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$installDir", "User")
    $env:PATH = "$env:PATH;$installDir"
}

# Verify installation
Write-Host ""
try {
    $installedVersion = & $binPath version 2>&1
    Write-Host "  Installation successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Installed to: $binPath" -ForegroundColor Gray
    Write-Host "  $installedVersion" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Run 'agenthelper' to get started." -ForegroundColor Cyan
    Write-Host "  (You may need to restart your terminal for PATH changes to take effect)" -ForegroundColor Yellow
} catch {
    Write-Host "  Warning: Installation completed but verification failed" -ForegroundColor Yellow
    Write-Host "  Binary location: $binPath" -ForegroundColor Gray
}

Write-Host ""
