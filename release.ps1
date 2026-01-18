<#
.SYNOPSIS
    Automated release script using Conventional Commits

.DESCRIPTION
    Analyzes git commits since the last tag and automatically determines
    the appropriate version bump based on Conventional Commits format:

    - fix:           → PATCH (1.0.x)  Bug fixes
    - feat:          → MINOR (1.x.0)  New features
    - feat!:         → MAJOR (x.0.0)  Breaking changes
    - BREAKING CHANGE: → MAJOR (x.0.0)  Breaking changes

    Other prefixes (docs:, chore:, refactor:, test:, style:) don't trigger releases
    but will be included if there are fix: or feat: commits.

.PARAMETER DryRun
    Analyze commits and show what would happen without making changes

.PARAMETER Push
    Push commits and tags to remote after release

.PARAMETER Force
    Create release even if no conventional commits found (defaults to patch)

.EXAMPLE
    .\release.ps1 -DryRun
    # Shows what version bump would occur

.EXAMPLE
    .\release.ps1 -Push
    # Create release and push to remote

.EXAMPLE
    .\release.ps1 -Force
    # Force a patch release even without conventional commits
#>

param(
    [switch]$DryRun,
    [switch]$Push,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "  $('─' * ($Text.Length + 2))" -ForegroundColor DarkGray
}

function Write-Step {
    param([string]$Text, [string]$Status = 'info')
    $symbol = switch ($Status) {
        'ok'    { '✓'; $color = 'Green' }
        'warn'  { '⚠'; $color = 'Yellow' }
        'error' { '✗'; $color = 'Red' }
        'skip'  { '○'; $color = 'DarkGray' }
        default { '•'; $color = 'White' }
    }
    Write-Host "  $symbol " -ForegroundColor $color -NoNewline
    Write-Host $Text
}

function Get-ConventionalCommitType {
    param([string]$Message)

    # Check for breaking changes first
    if ($Message -match 'BREAKING CHANGE:|^[a-z]+!:') {
        return 'major'
    }

    # Check for feat
    if ($Message -match '^feat(\(.+\))?:') {
        return 'minor'
    }

    # Check for fix
    if ($Message -match '^fix(\(.+\))?:') {
        return 'patch'
    }

    # Other conventional commits (no version bump)
    if ($Message -match '^(docs|chore|refactor|test|style|perf|ci|build)(\(.+\))?:') {
        return 'none'
    }

    return $null  # Not a conventional commit
}

# ─────────────────────────────────────────────────────────────────────────────
# Pre-flight Checks
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Release Automation"

# Check if git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Step "Git is not installed" -Status error
    exit 1
}

# Check if we're in a git repository
$gitRoot = git rev-parse --show-toplevel 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Step "Not a git repository" -Status error
    Write-Host ""
    Write-Host "  Initialize with: git init" -ForegroundColor DarkGray
    exit 1
}

# Check for uncommitted changes
$status = git status --porcelain 2>&1
if ($status) {
    Write-Step "Uncommitted changes detected" -Status warn
    Write-Host ""
    $status | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Write-Host ""

    if (-not $DryRun) {
        $confirm = Read-Host "  Continue anyway? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Step "Aborted" -Status skip
            exit 0
        }
    }
}

Write-Step "Git repository OK" -Status ok

# ─────────────────────────────────────────────────────────────────────────────
# Analyze Commits
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Analyzing Commits"

# Get last tag
$lastTag = git describe --tags --abbrev=0 2>&1
if ($LASTEXITCODE -ne 0) {
    $lastTag = $null
    Write-Step "No previous tags found (first release)" -Status info
    $commitRange = "HEAD"
}
else {
    Write-Step "Last tag: $lastTag" -Status ok
    $commitRange = "$lastTag..HEAD"
}

# Get commits since last tag
$commits = git log $commitRange --pretty=format:"%s" 2>&1
if (-not $commits -or $commits.Count -eq 0) {
    Write-Step "No new commits since last tag" -Status warn

    if (-not $Force) {
        Write-Host ""
        Write-Host "  Use -Force to create a release anyway" -ForegroundColor DarkGray
        exit 0
    }
}

# Analyze commit types
$commitList = if ($commits -is [string]) { @($commits) } else { $commits }
$analysis = @{
    major = @()
    minor = @()
    patch = @()
    other = @()
    nonConventional = @()
}

foreach ($commit in $commitList) {
    $type = Get-ConventionalCommitType -Message $commit

    switch ($type) {
        'major' { $analysis.major += $commit }
        'minor' { $analysis.minor += $commit }
        'patch' { $analysis.patch += $commit }
        'none'  { $analysis.other += $commit }
        default { $analysis.nonConventional += $commit }
    }
}

# Display analysis
Write-Host ""
if ($analysis.major.Count -gt 0) {
    Write-Host "  BREAKING CHANGES ($($analysis.major.Count)):" -ForegroundColor Red
    $analysis.major | ForEach-Object { Write-Host "    • $_" -ForegroundColor DarkGray }
}
if ($analysis.minor.Count -gt 0) {
    Write-Host "  Features ($($analysis.minor.Count)):" -ForegroundColor Yellow
    $analysis.minor | ForEach-Object { Write-Host "    • $_" -ForegroundColor DarkGray }
}
if ($analysis.patch.Count -gt 0) {
    Write-Host "  Fixes ($($analysis.patch.Count)):" -ForegroundColor Green
    $analysis.patch | ForEach-Object { Write-Host "    • $_" -ForegroundColor DarkGray }
}
if ($analysis.other.Count -gt 0) {
    Write-Host "  Other ($($analysis.other.Count)):" -ForegroundColor DarkGray
    $analysis.other | ForEach-Object { Write-Host "    • $_" -ForegroundColor DarkGray }
}
if ($analysis.nonConventional.Count -gt 0) {
    Write-Host "  Non-conventional ($($analysis.nonConventional.Count)):" -ForegroundColor DarkGray
    $analysis.nonConventional | Select-Object -First 5 | ForEach-Object {
        Write-Host "    • $_" -ForegroundColor DarkGray
    }
    if ($analysis.nonConventional.Count -gt 5) {
        Write-Host "    ... and $($analysis.nonConventional.Count - 5) more" -ForegroundColor DarkGray
    }
}

# Determine bump type
$bumpType = $null
if ($analysis.major.Count -gt 0) {
    $bumpType = 'major'
}
elseif ($analysis.minor.Count -gt 0) {
    $bumpType = 'minor'
}
elseif ($analysis.patch.Count -gt 0) {
    $bumpType = 'patch'
}
elseif ($Force) {
    $bumpType = 'patch'
    Write-Host ""
    Write-Step "No conventional commits, forcing patch release" -Status warn
}

if (-not $bumpType) {
    Write-Host ""
    Write-Step "No release-triggering commits found" -Status skip
    Write-Host ""
    Write-Host "  Commits that trigger releases:" -ForegroundColor DarkGray
    Write-Host "    fix: ...           → patch release" -ForegroundColor DarkGray
    Write-Host "    feat: ...          → minor release" -ForegroundColor DarkGray
    Write-Host "    feat!: ...         → major release" -ForegroundColor DarkGray
    Write-Host "    BREAKING CHANGE:   → major release" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Create Release
# ─────────────────────────────────────────────────────────────────────────────

Write-Header "Creating Release"

Write-Step "Bump type: $bumpType" -Status info

if ($DryRun) {
    Write-Host ""
    # Run bump-version in dry-run mode
    $newVersion = & "$PSScriptRoot\bump-version.ps1" -Type $bumpType -DryRun
    Write-Host ""
    Write-Step "[DryRun] Would create tag: v$newVersion" -Status skip
    Write-Step "[DryRun] No changes made" -Status skip
    exit 0
}

# Bump version
$newVersion = & "$PSScriptRoot\bump-version.ps1" -Type $bumpType

if (-not $newVersion) {
    Write-Step "Version bump failed" -Status error
    exit 1
}

# Stage and commit
Write-Host ""
git add CodingAgentsHelper.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Step "Failed to stage changes" -Status error
    exit 1
}

$commitMessage = "chore(release): v$newVersion"
git commit -m $commitMessage
if ($LASTEXITCODE -ne 0) {
    Write-Step "Failed to create commit" -Status error
    exit 1
}
Write-Step "Created commit: $commitMessage" -Status ok

# Create tag
$tagName = "v$newVersion"
git tag -a $tagName -m "Release $tagName"
if ($LASTEXITCODE -ne 0) {
    Write-Step "Failed to create tag" -Status error
    exit 1
}
Write-Step "Created tag: $tagName" -Status ok

# ─────────────────────────────────────────────────────────────────────────────
# Push to Remote
# ─────────────────────────────────────────────────────────────────────────────

if ($Push) {
    Write-Header "Pushing to Remote"

    # Check if remote exists
    $remote = git remote 2>&1
    if (-not $remote) {
        Write-Step "No remote configured" -Status warn
        Write-Host "  Add remote with: git remote add origin <url>" -ForegroundColor DarkGray
    }
    else {
        git push
        if ($LASTEXITCODE -ne 0) {
            Write-Step "Failed to push commits" -Status error
        }
        else {
            Write-Step "Pushed commits" -Status ok
        }

        git push --tags
        if ($LASTEXITCODE -ne 0) {
            Write-Step "Failed to push tags" -Status error
        }
        else {
            Write-Step "Pushed tags" -Status ok
        }
    }
}
else {
    Write-Host ""
    Write-Host "  Push manually with:" -ForegroundColor DarkGray
    Write-Host "    git push && git push --tags" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  ════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✓ Released v$newVersion" -ForegroundColor Green
Write-Host "  ════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
