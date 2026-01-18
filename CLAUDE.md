# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Single-file PowerShell script (`CodingAgentsHelper.ps1`) that manages coding agent CLI tools on Windows. Supports both native Windows tools and WSL-based tools with install, update, repair, and status checking capabilities.

## Running the Script

```powershell
# Interactive mode
.\CodingAgentsHelper.ps1

# Check status of all tools
.\CodingAgentsHelper.ps1 -Status

# JSON output for scripting
.\CodingAgentsHelper.ps1 -Status -OutputFormat Json

# Install a specific tool
.\CodingAgentsHelper.ps1 -Install ClaudeCode

# Install all tools
.\CodingAgentsHelper.ps1 -Install All -PreferredMethod WinGet

# Update tools
.\CodingAgentsHelper.ps1 -Update All

# Check environment (prerequisites, API keys)
.\CodingAgentsHelper.ps1 -Environment
```

## Syntax Validation

```powershell
# Parse file for syntax errors
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    'CodingAgentsHelper.ps1', [ref]$null, [ref]$errors
)
$errors  # Should be empty
```

## Architecture

The script is organized into `#region` blocks:

| Region | Purpose |
|--------|---------|
| `Tool Definitions` | `$script:ToolDefinitions` hashtable - each tool has Name, Command, VersionCmd, VersionPattern, InstallMethods, UninstallMethods, VersionSource, RequiresWSL |
| `Box-Drawing Characters` | `$script:BoxChars`, `$script:StatusSymbols`, `$script:MenuIcons` for UI rendering |
| `UI Helper Functions` | `Write-BoxLine`, `Write-BoxText`, `Write-TableRow`, `Write-TableSeparator` |
| `Helper Functions` | `Write-Log`, `Write-ColorOutput`, `Test-CommandExists`, `Test-WSLInstalled`, `Compare-Version` |
| `Version Fetching` | `Get-LatestNpmVersion`, `Get-LatestGitHubVersion`, `Get-LatestPyPIVersion`, `Get-InstalledVersion`, `Get-AllToolStatus` |
| `Installation Functions` | `Install-CodingTool`, `Install-AllTools`, `Get-BestInstallMethod` |
| `Update Functions` | `Update-CodingTool`, `Update-AllTools` |
| `Repair Functions` | `Repair-ToolInstallation` |
| `Environment Functions` | `Get-EnvironmentReport`, `Show-EnvironmentReport` |
| `UI Functions` | `Show-Banner`, `Show-StatusTable`, `Show-MainMenu`, `Show-InstallMenu`, etc. |
| `Main Entry Point` | Parameter set handling and `Start-InteractiveMode` |

## Adding a New Tool

Add entry to `$script:ToolDefinitions` (around line 122):

```powershell
NewTool = @{
    Name = "Display Name"
    Command = "command-name"
    VersionCmd = "command-name --version"
    VersionPattern = '(\d+\.\d+\.\d+)'
    UpdateCmd = "update-command"
    RequiresWSL = $false  # or $true for WSL-only tools
    VersionSource = @{
        Type = "npm"  # or "github", "pypi", "unknown"
        Package = "package-name"  # for npm/pypi
        # Owner = "owner"; Repo = "repo"  # for github
    }
    InstallMethods = @{
        WinGet = "winget install ..."
        npm = "npm install -g ..."
        # WSL = 'wsl -e bash -c "..."'  # for WSL tools
    }
    UninstallMethods = @{
        WinGet = "winget uninstall ..."
    }
    EnvVars = @("API_KEY_NAME")  # Optional: related env vars
}
```

Then add menu entries in `Show-InstallMenu`, `Show-UpdateMenu`, `Show-RepairMenu`, and update `Get-ToolKeyFromMenuChoice`.

## Encoding

The file must be saved as **UTF-8 with BOM** for PowerShell to correctly handle the Unicode box-drawing characters. If characters display incorrectly, re-save with proper encoding.

## Supported Tools

**Native Windows:** Claude Code, GitHub Copilot CLI, OpenCode, OpenAI Codex CLI, Aider, VS Code, VS Code Insiders

**WSL Required:** Cursor CLI, Cline, Kiro CLI (Amazon Q)

## Versioning & Releases

This project uses **Conventional Commits** for automated versioning:

```powershell
# Commit message prefixes determine version bumps:
git commit -m "fix: ..."     # → PATCH (1.0.x)
git commit -m "feat: ..."    # → MINOR (1.x.0)
git commit -m "feat!: ..."   # → MAJOR (x.0.0)

# Create release (analyzes commits, bumps version, creates tag)
.\release.ps1 -DryRun   # Preview
.\release.ps1 -Push     # Release and push

# Manual version bump
.\bump-version.ps1 -Type patch|minor|major
```

The version is stored in `$script:Version` (line ~115) in `CodingAgentsHelper.ps1`.
