<#
.SYNOPSIS
    Bumps the version number in CodingAgentsHelper.ps1

.DESCRIPTION
    Updates the $script:Version variable according to Semantic Versioning (SemVer).
    - MAJOR: Breaking changes (incompatible API changes)
    - MINOR: New features (backwards compatible)
    - PATCH: Bug fixes (backwards compatible)

.PARAMETER Type
    The type of version bump: major, minor, or patch

.PARAMETER DryRun
    Show what would happen without making changes

.EXAMPLE
    .\bump-version.ps1 -Type patch
    # 1.0.0 → 1.0.1

.EXAMPLE
    .\bump-version.ps1 -Type minor -DryRun
    # Shows: 1.0.1 → 1.1.0 (without changing the file)
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('major', 'minor', 'patch')]
    [string]$Type,

    [switch]$DryRun
)

$scriptFile = Join-Path $PSScriptRoot 'CodingAgentsHelper.ps1'

if (-not (Test-Path $scriptFile)) {
    Write-Host "Error: CodingAgentsHelper.ps1 not found" -ForegroundColor Red
    exit 1
}

# Read file content
$content = Get-Content $scriptFile -Raw -Encoding UTF8

# Extract current version
if ($content -match '\$script:Version\s*=\s*"(\d+)\.(\d+)\.(\d+)"') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $oldVersion = "$major.$minor.$patch"

    # Calculate new version
    switch ($Type) {
        'major' {
            $major++
            $minor = 0
            $patch = 0
        }
        'minor' {
            $minor++
            $patch = 0
        }
        'patch' {
            $patch++
        }
    }

    $newVersion = "$major.$minor.$patch"

    Write-Host ""
    Write-Host "  Version Bump ($Type)" -ForegroundColor Cyan
    Write-Host "  ─────────────────────" -ForegroundColor DarkGray
    Write-Host "  $oldVersion " -NoNewline -ForegroundColor Yellow
    Write-Host "→ " -NoNewline -ForegroundColor DarkGray
    Write-Host "$newVersion" -ForegroundColor Green
    Write-Host ""

    if ($DryRun) {
        Write-Host "  [DryRun] No changes made" -ForegroundColor DarkGray
    }
    else {
        # Replace version in content
        $newContent = $content -replace '\$script:Version\s*=\s*"\d+\.\d+\.\d+"', "`$script:Version = `"$newVersion`""

        # Write back with UTF8 BOM (required for PowerShell Unicode support)
        Set-Content $scriptFile $newContent -Encoding UTF8

        Write-Host "  ✓ Updated CodingAgentsHelper.ps1" -ForegroundColor Green
    }

    # Return the new version for use in other scripts
    return $newVersion
}
else {
    Write-Host "Error: Could not find version pattern in script" -ForegroundColor Red
    exit 1
}
